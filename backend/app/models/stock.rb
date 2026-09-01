class Stock < ApplicationRecord
  include Restorable
  include Auditable
  # La cantidad ya se rastrea en stock_movimientos (con usuario y motivo): auditarla acá sería
  # duplicar y generar ruido en cada venta/dispensa. Auditamos solo las ediciones reales
  # (precio, costo, descripción, categoría, estado, etc.).
  no_auditar :cantidad, :lote_origen_consumido_g
  belongs_to :sede,     optional: true
  belongs_to :lote,     optional: true
  belongs_to :pesada,   optional: true
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :genetica, optional: true
  belongs_to :producido_desde_stock, class_name: 'Stock', optional: true

  # Los pesajes de manicura que llenaron este contenedor. El vínculo fino stock ↔ planta vive
  # acá (`pesaje.pesadas_plantas`): la trazabilidad lo leía sólo por `pesada` —el flujo viejo—,
  # no encontraba nada y caía a "todas las plantas del lote".
  # `class_name` explícito: Rails infiere 'PesajesManicura' del nombre de la asociación (el
  # singular de "manicura" no existe) y revienta al tocarla. Mismo caso que :pesadas_plantas.
  has_many :pesajes_manicura, class_name: 'PesajeManicura', dependent: :nullify
  has_many :stock_movimientos, dependent: :destroy
  has_many :dispensaciones, class_name: 'Dispensacion', dependent: :nullify
  has_many :reservas, dependent: :nullify
  # Provisiones de eventos del salón que apartan este stock (ver EventoBarProvision).
  has_many :provisiones_evento, class_name: 'EventoBarProvision', as: :provisionable, dependent: :destroy
  # Los turnos de mostrador que tienen este stock sobre la mesa. Apartan igual que un evento:
  # bloquean la cantidad sin descontarla.
  has_many :items_mostrador, class_name: 'TurnoMostradorItem', dependent: :destroy
  has_many :derivados, class_name: 'Stock', foreign_key: :producido_desde_stock_id, dependent: :nullify

  ORIGENES         = %w[lote derivado_lote compra_externa].freeze
  FORMAS_PRODUCTO  = %w[flor_seca hash aceite tintura crema capsula comestible prensado preroll otro externo].freeze
  UNIDADES         = %w[g ml un].freeze
  CATEGORIAS_EXTERNA = %w[merch bebida insumo otros].freeze
  ESTADOS          = %w[pendiente_asignacion asignado agotado].freeze

  # Cómo se cierra un stock que no se va a dispensar. El admin lo decide y lo dice: cada motivo
  # deja un movimiento distinto, y sólo `destruido` cuenta como PÉRDIDA.
  #
  # Existe porque una organización que sólo produce no tiene salida legítima: su única opción era
  # descartar, que lo anotaba como merma y declaraba destruido producto que se entregó entero. Y
  # como el lote se finaliza cuando su stock llega a cero, sin esta puerta sus lotes quedaban
  # abiertos para siempre y la trazabilidad nunca cerraba el balance.
  MOTIVOS_FINALIZACION = {
    'entregado'   => 'Entregado a otra organización',
    'vendido'     => 'Vendido',
    'regalado'    => 'Regalado',
    'uso_interno' => 'Uso interno',
    'destruido'   => 'Destruido / descartado',
  }.freeze

  # El único que es pérdida de verdad. El resto son salidas: el producto existe, está en otro lado.
  MOTIVOS_PERDIDA = %w[destruido].freeze

  def self.tipo_movimiento_para(motivo)
    MOTIVOS_PERDIDA.include?(motivo) ? 'merma' : 'salida'
  end
  # Para qué está habilitado el stock: dispensar a pacientes, usarse como materia prima de
  # producción (manufacturar derivados), ambas, o ninguna (apartado / cuarentena / testeo).
  DISPONIBILIDADES = %w[dispensa produccion ambas ninguna].freeze

  validates :origen,        inclusion: { in: ORIGENES }
  validates :forma_producto, inclusion: { in: FORMAS_PRODUCTO }
  validates :unidad,        inclusion: { in: UNIDADES }
  validates :cantidad,      numericality: { greater_than_or_equal_to: 0 }
  validates :estado,        inclusion: { in: ESTADOS }
  validates :disponibilidad, inclusion: { in: DISPONIBILIDADES }
  validates :costo_unitario_ars,  numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :precio_sugerido_ars, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  attr_accessor :es_split

  validate :validar_segun_origen

  before_validation :set_club_id, on: :create
  before_create :set_cantidad_inicial
  before_create :generar_numero_lote_producto
  before_create :generar_codigo_qr
  before_create :descontar_lote_origen_si_corresponde, unless: -> { es_split }
  # Cuando el stock de un lote se agota, el lote pasa a 'finalizado' (si era el último).
  after_save :finalizar_lote_si_agotado, if: -> { saved_change_to_estado? && estado == 'agotado' && lote_id.present? }

  scope :regulatorios,             -> { where(origen: %w[lote derivado_lote]) }
  scope :sociales,                 -> { where(origen: 'compra_externa') }
  scope :disponibles,              -> { where('cantidad > 0') }
  scope :pendientes_asignacion,    -> { where(estado: 'pendiente_asignacion') }
  scope :asignados,                -> { where(estado: 'asignado') }
  scope :del_club,                 -> { where(sede_id: nil) }
  # Habilitado para... (la disponibilidad 'ambas' entra en ambos).
  scope :para_dispensa,            -> { where(disponibilidad: %w[dispensa ambas]) }
  scope :para_produccion,          -> { where(disponibilidad: %w[produccion ambas]) }

  def pendiente_asignacion? = estado == 'pendiente_asignacion'
  def asignado?             = estado == 'asignado'
  def agotado?              = estado == 'agotado'
  def del_club?             = sede_id.nil?
  def apto_dispensa?        = %w[dispensa ambas].include?(disponibilidad)
  def apto_produccion?      = %w[produccion ambas].include?(disponibilidad)

  # Stock comprometido pero todavía no descontado: envíos de dispensaciones en curso
  # MÁS reservas pendientes de entrega. Al entregar una reserva se crea la Dispensacion
  # (que descuenta el real) y la reserva pasa a 'entregada', dejando de contar acá — sin
  # doble conteo.
  def gramos_reservados
    envios   = dispensaciones.where(estado_envio: %w[pendiente en_viaje]).sum(:cantidad).to_f
    apartado = reservas.pendientes.sum(:cantidad).to_f
    envios + apartado + apartado_para_eventos.to_f + apartado_para_mostrador.to_f
  end

  # Cantidad que está SOBRE LA MESA de un mostrador con el turno abierto.
  #
  # Es la misma mecánica que el apartado de un evento —bloquea, no descuenta— con otro
  # destinatario: mientras el mostrador la tiene cargada, nadie más la ve libre (ni una reserva
  # de paciente ni la provisión de un evento). Se libera al cerrar el turno.
  #
  # Cargar el mostrador NO genera `StockMovimiento`: el gramo no salió de la organización ni
  # cambió de sede, sigue siendo esta misma fila. Lo único que cambia es quién responde por él, y
  # ese rastro vive en el turno.
  def apartado_para_mostrador
    return @apartado_mostrador_precargado if defined?(@apartado_mostrador_precargado)
    return 0.to_d unless TurnoMostradorItem.table_exists?

    items_mostrador.en_turno_abierto.saldo_total
  end

  # Una query para toda una lista, en vez de una por stock.
  #
  # `cantidad_disponible_real` se llama en bucles sobre listados enteros (el inventario, el
  # carrito, el depósito): sin esto son 40 queries extra en una pantalla de 40 productos. El
  # apartado de eventos ya suma en Ruby con su propio N+1 — no hacía falta sumar otro.
  def self.precargar_apartado_mostrador(stocks)
    lista = Array(stocks)
    return lista if lista.empty? || !TurnoMostradorItem.table_exists?

    saldos = TurnoMostradorItem.unscoped.en_turno_abierto
                               .where(stock_id: lista.map(&:id))
                               .group(:stock_id)
                               .sum(Arel.sql(TurnoMostradorItem::SALDO_SQL))
    lista.each { |s| s.instance_variable_set(:@apartado_mostrador_precargado, saldos[s.id].to_d) }
    lista
  end

  # Lo que el mostrador de ESTA sede tiene apartado de este stock. Es el techo extra que puede
  # usar una dispensa hecha desde ese mostrador: para el resto del mundo sigue bloqueado, pero
  # para el mostrador que lo tiene cargado no es un bloqueo, es su stock.
  def apartado_en_mostrador_de_sede(sede_id)
    return 0.to_d if sede_id.blank? || !TurnoMostradorItem.table_exists?

    items_mostrador.en_turno_abierto
                   .joins(turno_mostrador: :mostrador)
                   .where(mostradores: { sede_id: sede_id })
                   .saldo_total
  end

  # Cantidad apartada por eventos del salón que todavía no se liberó (reservado − consumido).
  # TODO el stock (propio, externo y derivados) se APARTA para un evento, nunca se descuenta:
  # su única salida del inventario es la dispensación, que es la que deja la trazabilidad. El
  # apartado bloquea la cantidad para que ninguna dispensa ni reserva de paciente la pise —
  # misma mecánica que una Reserva de paciente, con otro destinatario.
  def apartado_para_eventos
    provisiones_evento.sum(&:saldo_apartado)
  end

  # Provisiones vivas de eventos EN CURSO (los que están sucediendo ahora). Son las únicas de las
  # que el dispensador puede dispensar: durante el evento, lo apartado deja de ser un bloqueo y
  # pasa a ser el stock del evento. Antes (planificado / en venta) sigue reservado a futuro.
  def apartados_en_curso
    provisiones_evento.select { |p| p.saldo_apartado.positive? && p.evento_bar&.estado == 'en_curso' }
  end

  def apartado_en_evento(evento_bar_id)
    apartados_en_curso.select { |p| p.evento_bar_id == evento_bar_id.to_i }.sum(&:saldo_apartado)
  end

  # Techo para dispensar: lo libre, más lo apartado del evento del que se está dispensando.
  # Sin `desde_evento` es el disponible de siempre — una dispensa de mostrador no se come lo
  # apartado, y una reserva de paciente a futuro tampoco (usa cantidad_disponible_real).
  def disponible_para_dispensa(desde_evento: nil)
    libre = cantidad_disponible_real.to_d
    return libre if desde_evento.blank?

    libre + apartado_en_evento(desde_evento)
  end

  # Salida de lo consumido en un evento sin dispensar a nadie identificable (degustación,
  # muestra). Descuenta de verdad y deja el rastro con el evento.
  def consumo_interno_evento!(cantidad:, usuario:, evento:)
    cantidad = cantidad.to_d
    return if cantidad <= 0
    raise ArgumentError, "Sin stock suficiente de #{etiqueta}" if cantidad > self.cantidad.to_d

    transaction do
      update!(cantidad: self.cantidad.to_d - cantidad)
      stock_movimientos.create!(tipo: 'consumo_evento', gramos: -cantidad, usuario: usuario,
                                notas: "Consumo en el evento «#{evento&.nombre}»")
    end
  end

  def cantidad_disponible_real
    # OJO: los envíos pendientes/en viaje YA se descontaron de `cantidad` al crearse la
    # dispensación (after_create :decrementar_stock). NO se vuelven a restar acá (eso era un
    # doble descuento que dejaba el disponible en ~0 tras una entrega grande). Solo restamos las
    # reservas (apartado), que comprometen stock SIN descontar el real, y lo apartado por eventos.
    comprometido = reservas.pendientes.sum(:cantidad).to_f + apartado_para_eventos.to_f +
                   apartado_para_mostrador.to_f
    [cantidad.to_f - comprometido, 0].max
  end

  def dias_para_vencimiento
    return nil unless fecha_vencimiento_est
    (fecha_vencimiento_est - Time.zone.today).to_i
  end

  def estado_vencimiento
    return nil unless fecha_vencimiento_est
    dias = dias_para_vencimiento
    if    dias < 0  then 'vencido'
    elsif dias <= 7 then 'critico'
    elsif dias <= 30 then 'proximo'
    else 'ok'
    end
  end

  def asignar!(sede:, usuario:, notas: nil)
    ActiveRecord::Base.transaction do
      update!(sede: sede, estado: 'asignado')
      stock_movimientos.create!(
        tipo:             'transferencia',
        gramos:           cantidad,
        sede_origen_id:   nil,
        sede_destino_id:  sede.id,
        usuario:          usuario,
        notas:            notas,
      )
    end
  end

  delegate :nombre,  to: :lote, prefix: :lote, allow_nil: true
  delegate :codigo,  to: :lote, prefix: :lote, allow_nil: true

  def regulatorio?
    origen.in?(%w[lote derivado_lote])
  end

  # ── Provisión de eventos del salón ─────────────────────────────────────────
  # Nombre legible para listados donde el stock convive con productos del bar e insumos
  # (buscador de provisión, POS). Genética + forma, o la descripción si es externo.
  def etiqueta
    base = descripcion.presence || (genetica || lote&.genetica)&.nombre
    forma = forma_producto.to_s.tr('_', ' ')
    [base, base.present? ? "(#{forma})" : forma.capitalize].compact.join(' ')
  end

  private

  def set_club_id
    self.club_id ||= sede&.club_id || lote&.club_id
  end

  # "Cantidad inicial" = lo que entró originalmente. Para stock externo/derivado nace con
  # su cantidad; el de manicura nace en 0 y se acumula vía produccion en PesajeManicura#confirmar!.
  def set_cantidad_inicial
    self.cantidad_inicial ||= cantidad
  end

  public

  # ── VERDAD ÚNICA de las cantidades de un stock ─────────────────────────────────
  # cantidad_inicial = lo que se INGRESÓ al crear el stock (externo: lo cargado; de lote: la
  #                    suma del pesaje de cada planta). Es editable: si se corrige, ese número
  #                    pasa a ser el inicial. Es el "Total". Las operaciones NO lo tocan.
  # cantidad         = lo que hay AHORA, ya descontadas dispensaciones, producción y traslados.
  #                    Es el "Actual". Lo mutan las operaciones.
  def disponible = cantidad_disponible_real.to_d # lo que queda libre (actual − reservado)

  def generar_numero_lote_producto
    return if numero_lote_producto.present?
    return unless club_id
    year = Time.zone.today.strftime("%y")
    loop do
      result = ActiveRecord::Base.connection.execute(
        "UPDATE clubs SET lote_numero_seq = COALESCE(lote_numero_seq, 0) + 1 WHERE id = #{club_id.to_i} RETURNING lote_numero_seq"
      )
      seq = result.first['lote_numero_seq']
      candidate = "ST-#{year}-#{seq.to_s.rjust(4, '0')}"
      unless Stock.where(club_id: club_id).exists?(numero_lote_producto: candidate)
        self.numero_lote_producto = candidate
        break
      end
    end
  end

  def generar_codigo_qr
    return if codigo_qr.present?
    cid = club_id || sede&.club_id || lote&.club_id
    return unless cid
    self.codigo_qr = "S-#{cid}-#{Time.now.to_i}-#{SecureRandom.hex(4)}"
  end

  def validar_segun_origen
    case origen
    when 'lote'
      errors.add(:lote_id, 'es obligatorio para origen lote')        if lote_id.blank?
      # el stock de un lote es flor_seca (lo genera la confirmación de manicura)
    when 'derivado_lote'
      return if es_split
      errors.add(:lote_id, 'es obligatorio para derivados')           if lote_id.blank?
      errors.add(:lote_origen_consumido_g, 'debe ser mayor a 0')     if lote_origen_consumido_g.to_d <= 0
      errors.add(:forma_producto, 'no puede ser flor_seca para derivados') if forma_producto == 'flor_seca'
      # De 100 g de flor no pueden salir 120 g de hash: eso es materia que apareció de la nada.
      #
      # Pero la regla SÓLO vale cuando el resultado se mide en gramos. De 100 g salen 200 prerolls
      # de medio gramo, o 400 cápsulas: el número es mayor y está perfecto, porque la unidad es
      # otra. Comparar 200 unidades contra 100 gramos rechazaba el caso principal del preroll —y
      # el mensaje de error hasta les decía "gramos" a los prerolls, que es la confusión de fondo.
      if unidad == 'g' && cantidad.to_d > lote_origen_consumido_g.to_d
        errors.add(:cantidad, "no puede superar los gramos consumidos (#{lote_origen_consumido_g}g consumidos → #{cantidad}g resultado)")
      end
    when 'compra_externa'
      errors.add(:proveedor, 'es obligatorio para compra externa') if proveedor.blank?
      errors.add(:lote_id,   'debe ser nulo para compra externa')  if lote_id.present?
    end
  end

  # Quién produjo el movimiento que dejó este stock en cero. No es una columna: viaja en
  # memoria desde el llamador (la dispensación, el ajuste de inventario) hasta el callback,
  # porque el evento que cierra el lote necesita un autor y un `after_save` no tiene
  # `current_user`.
  attr_accessor :usuario_movimiento

  # Marca el stock como agotado cuando ya no queda nada. Hay que llamarlo explícitamente
  # después de descontar: `decrement!` baja la cantidad pero NO toca el estado, así que sin
  # esto un stock dispensado hasta el último gramo quedaba 'asignado' con cantidad 0 y el
  # lote no se cerraba nunca.
  def marcar_agotado_si_vacio!(usuario: nil)
    return if agotado? || cantidad.to_d.positive?

    self.usuario_movimiento = usuario
    update!(estado: 'agotado')
  end

  def finalizar_lote_si_agotado
    lote&.finalizar_si_stock_agotado!(usuario: usuario_movimiento)
  end

  def descontar_lote_origen_si_corresponde
    return unless origen == 'derivado_lote' && lote_id.present? && lote_origen_consumido_g.to_d > 0

    stock_flor = Stock.find_by(lote_id: lote_id, forma_producto: 'flor_seca', origen: 'lote')
    unless stock_flor
      errors.add(:base, "No existe stock de flor seca para el lote #{lote_id}")
      throw :abort
    end
    if stock_flor.cantidad < lote_origen_consumido_g
      errors.add(:lote_origen_consumido_g,
        "excede el stock disponible de flor seca del lote (#{stock_flor.cantidad}g disponibles)")
      throw :abort
    end

    stock_flor.decrement!(:cantidad, lote_origen_consumido_g)
  end
end
