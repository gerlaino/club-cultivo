class PesajeManicura < ApplicationRecord
  include Transmite
  transmite_como 'pesajes'
  include Restorable
  self.table_name = 'pesajes_manicura'

  ESTADOS = %w[borrador enviado confirmado].freeze

  belongs_to :lote
  belongs_to :manicurador,    class_name: 'User'
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :stock,           optional: true
  belongs_to :confirmado_por,  class_name: 'User', optional: true, foreign_key: :confirmado_por_id
  # class_name explícito: el nombre de la asociación inferiría 'PesadasPlanta' (con 's'),
  # pero el modelo real es PesadaPlanta. Sin esto, cualquier acceso a pesadas_plantas rompe.
  has_many   :pesadas_plantas,  class_name: 'PesadaPlanta', dependent: :nullify
  # A qué frascos fue el peso confirmado, y cuánto a cada uno (1-oct-2026: copones y bajos).
  has_many   :destinos, class_name: 'PesajeDestino', dependent: :destroy

  validates :estado,       inclusion: { in: ESTADOS }
  validates :fecha_pesaje, presence: true

  scope :borradores,  -> { where(estado: 'borrador') }
  scope :enviados,    -> { where(estado: 'enviado') }
  scope :confirmados, -> { where(estado: 'confirmado') }
  scope :pendientes,  -> { where(estado: %w[borrador enviado]) }
  scope :recientes,   -> { order(fecha_pesaje: :desc, created_at: :desc) }

  # Peso del pesaje: si hay registros por planta (flujo QR) los suma; si no, usa el
  # peso declarado en carga manual (peso_total_g). Un pesaje es QR o manual, nunca ambos.
  def peso_calculado_g
    if pesadas_plantas.exists?
      pesadas_plantas.sum(:peso_seco_g).to_d.round(2)
    else
      peso_total_g.to_d.round(2)
    end
  end

  def plantas_registradas_count
    pesadas_plantas.exists? ? pesadas_plantas.count : (plantas_count || 0)
  end

  # Carga manual sin QR: el manicura declara cantidad de plantas y peso total sobre el
  # borrador. Mismo modelo que el flujo QR, sin registros por planta.
  def cargar_manual!(plantas:, peso:, notas: nil)
    raise "Solo se puede cargar sobre un borrador" unless borrador?
    raise ArgumentError, "El peso debe ser mayor a 0" unless peso.to_d > 0
    raise "Este pesaje ya tiene plantas registradas por QR — no mezclar con carga manual" if pesadas_plantas.exists?

    update!(peso_total_g: peso.to_d, plantas_count: plantas.to_i, notas: notas.presence || self.notas)
  end

  # UNA PLANTA SE PESA EN UNA SOLA JORNADA (1-oct-2026). Pesarla en otra sumaba su peso dos veces
  # al stock al confirmar las dos. Para corregir un peso: en la misma jornada (borrador), se
  # vuelve a pesar; enviada, se reabre; confirmada, administración reajusta el pesaje.
  # Devuelve la pesada de la planta en otra jornada del lote (o nil).
  def self.pesada_en_otra_jornada(plant, salvo: nil)
    rel = PesadaPlanta.joins(:pesaje_manicura).includes(:pesaje_manicura)
                      .where(plant_id: plant.id, pesajes_manicura: { lote_id: plant.lote_id })
    rel = rel.where.not(pesaje_manicura_id: salvo.id) if salvo&.persisted?
    rel.order(:created_at).last
  end

  # Por qué no se puede pesar, dicho para la persona que está con la balanza. nil si se puede.
  def self.motivo_no_se_pesa(plant, salvo: nil)
    return "#{plant.nombre} está descartada: no se pesa" if plant.state == 'descartada'

    pp = pesada_en_otra_jornada(plant, salvo: salvo)
    return nil unless pp

    j = pp.pesaje_manicura
    dia = j.fecha_pesaje&.strftime('%d/%m')
    case j.estado
    when 'confirmado' then "#{plant.nombre} ya está pesada en la jornada del #{dia}, que ya se confirmó. Para corregir el peso, administración reajusta ese pesaje."
    when 'enviado'    then "#{plant.nombre} ya está pesada en la jornada del #{dia}, enviada y sin confirmar. Para corregir el peso, reabrí esa jornada."
    else                   "#{plant.nombre} ya está pesada en otra jornada abierta (del #{dia}, de #{j.manicurador&.first_name})."
    end
  end

  # Las plantas del lote que todavía se pueden pesar en esta jornada: no descartadas, sin peso y sin
  # pesada en otra jornada. Es lo que reparte «cargar el resto».
  def self.plantas_sin_pesar(lote, salvo: nil)
    otras = PesadaPlanta.joins(:pesaje_manicura).where(pesajes_manicura: { lote_id: lote.id })
    otras = otras.where.not(pesaje_manicura_id: salvo.id) if salvo&.persisted?
    lote.plants.where.not(state: 'descartada')
        .where('peso_seco IS NULL OR peso_seco <= 0')
        .where.not(id: otras.select(:plant_id))
  end

  def borrador?   = estado == 'borrador'
  def enviado?    = estado == 'enviado'
  def confirmado? = estado == 'confirmado'

  def enviar!
    peso = nil
    with_lock do
      raise "Solo un borrador puede enviarse a aprobación" unless borrador?

      peso = peso_calculado_g
      raise ArgumentError, "Registrá al menos una planta o una carga antes de enviar" if peso == 0

      update!(
        estado:        'enviado',
        enviado_at:    Time.current,
        peso_total_g:  peso,
        plantas_count: plantas_registradas_count,
      )

      AlertaInterna.create!(
        club:             club,
        tipo:             'manicura_aprobacion_pendiente',
        mensaje:          "#{manicurador.first_name} envió pesaje del lote #{lote.codigo} — #{plantas_count} plantas · #{peso}g",
        severidad:        'info',
        creada_por:       manicurador,
        destinada_a_role: 'admin',
        contexto:         {
          lote_id:           lote.id,
          lote_codigo:       lote.codigo,
          peso_seco_g:       peso,
          manicura_id:       manicurador.id,
          pesaje_manicura_id: id,
        },
      )
    end

    notificar_admins_pendiente(peso)
  end

  # Admin/supervisor confirms: edits peso if needed, picks or creates a stock container.
  #
  # CON CANDADO (1-oct-2026): dos confirmaciones del mismo pesaje a la vez —dos admins, o un doble
  # toque con mala señal— pasaban las dos, porque cada una miraba su copia «enviado», y el peso
  # entraba dos veces al frasco. `with_lock` relee la fila bloqueada: la segunda ya la ve confirmada.
  #
  # REPARTIR EN VARIOS FRASCOS (Germán, 1-oct-2026): `destinos: [{ stock_id:, gramos:, descripcion: }]`
  # —sin `stock_id` es un frasco nuevo, y `descripcion` lo nombra («copones», «bajos»)—. La suma
  # tiene que ser el peso confirmado. Sin `destinos`, todo va a `stock_id` (o a un frasco nuevo).
  MAX_DESTINOS = 10

  def confirmar!(confirmado_por:, peso_confirmado_g:, stock_id: nil, destinos: nil)
    peso = peso_confirmado_g.to_d
    raise ArgumentError, "El peso confirmado debe ser mayor a 0" unless peso > 0
    reparto = normalizar_destinos(destinos, peso, stock_id)

    with_lock do
      raise "Este pesaje ya fue confirmado" if confirmado?
      raise "Solo un pesaje enviado puede confirmarse" unless enviado?

      frascos = reparto.map do |d|
        st = d[:stock_id].present? ? contenedor_elegido!(d[:stock_id]) : crear_stock_contenedor!(descripcion: d[:descripcion])
        aplicar_a_stock!(st, d[:gramos], confirmado_por)
        st
      end
      stock_destino = frascos.first

      update!(
        estado:            'confirmado',
        confirmado_por:    confirmado_por,
        confirmado_at:     Time.current,
        peso_confirmado_g: peso,
        stock:             stock_destino,
      )

      AlertaInterna.create!(
        club:             club,
        tipo:             'manicura_aprobada',
        mensaje:          "Pesaje confirmado: lote #{lote.codigo} — #{peso}g",
        severidad:        'info',
        creada_por:       confirmado_por,
        destinada_a_role: 'manicura',
        contexto:         {
          lote_id:            lote.id,
          lote_codigo:        lote.codigo,
          peso_confirmado_g:  peso,
          stock_id:           stock_destino.id,
          stock_ids:          frascos.map(&:id),
          pesaje_manicura_id: id,
        },
      )

      lote.check_and_finalize_manicura!(finalizador: confirmado_por)
    end
  end

  # Con qué arranca la nota del movimiento de un reajuste: la trazabilidad lo reconoce por ella
  # (ese delta ya está en `cantidad_inicial`, no es una entrada ni una salida más).
  NOTA_REAJUSTE = 'Reajuste de pesaje del lote'.freeze

  # Corrige el peso de un pesaje YA confirmado y propaga la diferencia al stock que generó
  # (cantidad y cantidad_inicial), con un movimiento de auditoría. Es la forma coherente de
  # editar la "cantidad inicial" de un stock de lote: se edita el pesaje, no el agregado.
  #
  # Si el lote ya salió de manicura, su rendimiento (`rendimiento_real_g`, lo que leen Producción,
  # Plan vs real, INASE y el g/planta) se recalcula: antes quedaba con el peso viejo.
  #
  # POR FRASCO (1-oct-2026): si el pesaje se repartió, `stock_id` dice cuál se corrige y
  # `nuevo_peso` es lo que le tocó a ESE frasco; el peso confirmado del pesaje se mueve igual.
  def reajustar_peso_confirmado!(nuevo_peso:, usuario:, stock_id: nil)
    peso = nuevo_peso.to_d
    raise ArgumentError, "El peso debe ser mayor a 0" unless peso > 0

    with_lock do
      raise "Solo un pesaje confirmado puede reajustarse" unless confirmado?
      raise "Este pesaje no tiene stock asociado" if stock.nil?

      destino = destino_a_reajustar!(stock_id)
      frasco  = destino.stock
      delta   = peso - destino.gramos.to_d
      return self if delta.zero?

      frasco.lock!
      nueva_cant = frasco.cantidad.to_d + delta
      if nueva_cant < 0
        salio = (frasco.cantidad_inicial.to_d - frasco.cantidad.to_d).round(2)
        raise ArgumentError, "Del frasco #{frasco.numero_lote_producto} ya salieron #{salio.to_f} g: " \
                             "el pesaje no puede quedar en menos de #{(destino.gramos.to_d - frasco.cantidad.to_d).round(2).to_f} g"
      end

      frasco.update!(
        cantidad:         nueva_cant,
        cantidad_inicial: frasco.cantidad_inicial.to_d + delta,
      )
      frasco.stock_movimientos.create!(
        tipo: 'ajuste', gramos: delta, usuario: usuario,
        notas: "#{NOTA_REAJUSTE} #{lote.codigo}: #{destino.gramos.to_f}g → #{peso.to_f}g",
      )
      destino.update!(gramos: peso)
      update!(peso_confirmado_g: peso_confirmado_g.to_d + delta)
      # Un frasco ya vaciado al que el reajuste le devuelve gramos vuelve a estar abierto. Va antes
      # que el rendimiento: si el lote estaba finalizado, primero vuelve a curado.
      frasco.reabrir_si_tiene_producto!(usuario: usuario)
      lote.reload.recalcular_rendimiento_manicura!
    end
    self
  end

  # Los destinos del pesaje. Un pesaje viejo (confirmado antes del 1-oct-2026) no tiene filas: su
  # único destino es `stock` con todo el peso, y se escribe la fila la primera vez que hace falta.
  def destinos_efectivos!
    return destinos.includes(:stock).to_a if destinos.exists? || stock.nil?

    [destinos.create!(club: club, stock: stock, gramos: peso_confirmado_g.to_d)]
  end

  # Atajo del admin (última palabra): confirma un BORRADOR directo, sin pasar por 'enviado'
  # ni generar alertas de aprobación. Suma el peso al stock destino que resolvió el caller
  # (contenedor + sede). El caller corre lote.check_and_finalize_manicura! al final.
  #
  # `destinos` (1-oct-2026): igual que al confirmar, repartido en varios frascos —copones, bajos—;
  # la suma tiene que dar lo pesado. Sin `destinos`, todo va a `stock`.
  def confirmar_directo!(confirmado_por:, stock: nil, destinos: nil)
    raise "Solo un borrador puede confirmarse directo" unless borrador?
    peso = peso_calculado_g
    raise ArgumentError, "Registrá al menos una planta o una carga antes de confirmar" if peso.zero?

    if destinos.present?
      frascos = normalizar_destinos(destinos, peso, nil).map do |d|
        st = d[:stock_id].present? ? contenedor_elegido!(d[:stock_id]) : crear_stock_contenedor!(descripcion: d[:descripcion])
        aplicar_a_stock!(st, d[:gramos], confirmado_por)
        st
      end
      stock = frascos.first
    else
      raise ArgumentError, 'Falta a qué frasco va' if stock.nil?
      aplicar_a_stock!(stock, peso, confirmado_por)
    end
    update!(
      estado:            'confirmado',
      confirmado_por:    confirmado_por,
      confirmado_at:     Time.current,
      peso_total_g:      peso,
      peso_confirmado_g: peso,
      plantas_count:     plantas_registradas_count,
      stock:             stock,
    )
    self
  end

  private

  # El frasco que eligió quien confirma: de ESTE lote y de flor seca (uno de hash no recibe flor).
  # Puede estar vacío (agotado): se vuelve a usar y se reabre al recibir el peso (Germán, 1-oct-2026:
  # «hoy se dispensó todo, mañana manicuro y lo pongo en ese frasco»). Mismo criterio en
  # `registrar_directo` (`PesajesManicuraController#resolver_stock_destino!`).
  def contenedor_elegido!(stock_id)
    st = club.stocks.where(lote_id: lote.id).find(stock_id)
    raise ArgumentError, "El frasco #{st.numero_lote_producto} no es de flor seca: el pesaje va a un frasco de flor" unless st.forma_producto == 'flor_seca'
    st
  end

  # Contenedor nuevo de flor_seca para este lote (sin sede: se asigna aparte). `descripcion` lo
  # nombra cuando el pesaje se reparte («copones», «bajos»).
  def crear_stock_contenedor!(descripcion: nil)
    club.stocks.create!(
      lote:           lote,
      genetica:       lote.genetica,
      origen:         'lote',
      forma_producto: 'flor_seca',
      estado:         'pendiente_asignacion',
      cantidad:       0,
      unidad:         'g',
      descripcion:    descripcion.presence,
    )
  end

  # Suma `peso` al stock destino con un movimiento de producción, y anota el destino del pesaje.
  def aplicar_a_stock!(stock_destino, peso, usuario)
    stock_destino.stock_movimientos.create!(tipo: 'produccion', gramos: peso, usuario: usuario)
    stock_destino.increment!(:cantidad, peso)
    stock_destino.increment!(:cantidad_inicial, peso)
    d = destinos.find_or_initialize_by(stock: stock_destino)
    d.club   = club
    d.gramos = d.gramos.to_d + peso.to_d
    d.save!
    stock_destino.reabrir_si_tiene_producto!(usuario: usuario) # si estaba vacío, vuelve a abrirse
  end

  # El reparto pedido, validado ANTES de tocar nada: cada destino con gramos, sin repetir frasco, y
  # la suma igual al peso confirmado (al centésimo). Sin reparto, un único destino.
  def normalizar_destinos(destinos, peso, stock_id)
    lista = Array(destinos).map { |d| d.respond_to?(:to_unsafe_h) ? d.to_unsafe_h : d.to_h }.map(&:symbolize_keys)
    return [{ stock_id: stock_id.presence, gramos: peso }] if lista.empty?

    raise ArgumentError, "Se puede repartir en hasta #{MAX_DESTINOS} frascos" if lista.size > MAX_DESTINOS
    lista = lista.map { |d| { stock_id: d[:stock_id].presence, gramos: d[:gramos].to_d, descripcion: d[:descripcion].to_s.strip } }
    raise ArgumentError, 'Cada frasco lleva sus gramos' if lista.any? { |d| d[:gramos] <= 0 }
    ids = lista.filter_map { |d| d[:stock_id]&.to_i }
    raise ArgumentError, 'El mismo frasco está dos veces en el reparto' if ids.uniq.size != ids.size

    suma = lista.sum { |d| d[:gramos] }
    if (suma - peso).abs >= 0.01
      raise ArgumentError, "El reparto suma #{suma.to_f} g y el peso confirmado es #{peso.to_f} g: tienen que dar lo mismo"
    end
    lista
  end

  def destino_a_reajustar!(stock_id)
    todos = destinos_efectivos!
    if stock_id.present?
      d = todos.find { |x| x.stock_id == stock_id.to_i }
      raise ArgumentError, 'Ese frasco no recibió este pesaje' unless d
      return d
    end
    raise ArgumentError, 'Este pesaje se repartió en varios frascos: elegí cuál se corrige' if todos.size > 1

    todos.first
  end

  # Aviso push al admin: hay un pesaje esperando confirmación.
  def notificar_admins_pendiente(peso)
    PushNotificationService.notify_admins_async(
      club,
      tipo:  'pesaje_para_confirmar',
      title: "Pesaje para confirmar",
      body:  "#{manicurador.first_name} envió #{plantas_count} plantas · #{peso}g del lote #{lote.codigo}",
      url:   '/admin/pesajes-manicura',
    )
  rescue => e
    Rails.logger.warn("[PesajeManicura#enviar!] push falló: #{e.message}")
  end
end
