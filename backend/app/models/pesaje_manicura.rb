class PesajeManicura < ApplicationRecord
  self.table_name = 'pesajes_manicura'

  ESTADOS = %w[borrador enviado confirmado].freeze

  belongs_to :lote
  belongs_to :manicurador,    class_name: 'User'
  belongs_to :club
  belongs_to :stock,           optional: true
  belongs_to :confirmado_por,  class_name: 'User', optional: true, foreign_key: :confirmado_por_id
  # class_name explícito: el nombre de la asociación inferiría 'PesadasPlanta' (con 's'),
  # pero el modelo real es PesadaPlanta. Sin esto, cualquier acceso a pesadas_plantas rompe.
  has_many   :pesadas_plantas,  class_name: 'PesadaPlanta', dependent: :nullify

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

  def borrador?   = estado == 'borrador'
  def enviado?    = estado == 'enviado'
  def confirmado? = estado == 'confirmado'

  def enviar!
    raise "Solo un borrador puede enviarse a aprobación" unless borrador?

    peso = peso_calculado_g
    raise ArgumentError, "Registrá al menos una planta o una carga antes de enviar" if peso == 0

    ActiveRecord::Base.transaction do
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
  def confirmar!(confirmado_por:, peso_confirmado_g:, stock_id: nil)
    raise "Solo un pesaje enviado puede confirmarse" unless enviado?

    peso = peso_confirmado_g.to_d
    raise ArgumentError, "El peso confirmado debe ser mayor a 0" unless peso > 0

    ActiveRecord::Base.transaction do
      stock_destino = if stock_id.present?
        # Merge with existing stock for this lote
        club.stocks.where(lote_id: lote.id).find(stock_id)
      else
        # Create a new stock container (sede assigned separately via asignar!)
        club.stocks.create!(
          lote:          lote,
          genetica:      lote.genetica,
          origen:        'lote',
          forma_producto: 'flor_seca',
          estado:        'pendiente_asignacion',
          cantidad:      0,
          unidad:        'g',
        )
      end

      # Accumulate weight via movimiento
      stock_destino.stock_movimientos.create!(
        tipo:    'produccion',
        gramos:  peso,
        usuario: confirmado_por,
      )
      stock_destino.increment!(:cantidad, peso)
      stock_destino.increment!(:cantidad_inicial, peso)

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
          pesaje_manicura_id: id,
        },
      )

      lote.check_and_finalize_manicura!(finalizador: confirmado_por)
    end
  end

  private

  # Aviso push al admin: hay un pesaje esperando confirmación (reemplaza al push viejo
  # de manicura_pendiente, que apuntaba a la pantalla deprecada /aprobaciones).
  def notificar_admins_pendiente(peso)
    PushNotificationService.notify_admins_async(
      club,
      title: "Pesaje para confirmar",
      body:  "#{manicurador.first_name} envió #{plantas_count} plantas · #{peso}g del lote #{lote.codigo}",
      url:   '/admin/pesajes-manicura',
    )
  rescue => e
    Rails.logger.warn("[PesajeManicura#enviar!] push falló: #{e.message}")
  end
end
