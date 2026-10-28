# Reserva de dispensa: un socio aparta producto para retirar/recibir en una fecha futura.
#
# Es un modelo SEPARADO de Dispensacion a propósito: una reserva no descuenta stock real
# ni mueve plata como una dispensación; sólo BLOQUEA stock (vía Stock#gramos_reservados) y
# opcionalmente registra una seña. Recién al ENTREGARLA se crea la Dispensacion real, que
# corre todas sus validaciones (REPROCANN/crédito/stock) y callbacks financieros.
class Reserva < ApplicationRecord
  include Transmite
  transmite_como 'reservas'
  include Restorable
  include Auditable # sin campos cifrados → se audita completa (crear/editar/entregar/cancelar)
  # «solicitada» y «rechazada» son del pedido del portal (28-oct-2026): el paciente pide, y recién
  # cuando administración lo confirma pasa a «pendiente» y aparta (lo apartado lee sólo pendientes).
  ESTADOS          = %w[solicitada pendiente entregada cancelada vencida rechazada].freeze
  ORIGENES         = %w[organizacion portal].freeze
  DIAS_VENCIMIENTO = 7 # días posteriores a la fecha de entrega estimada sin retirar → vencida
  # Quién confirma o rechaza un pedido del portal (Germán, 28-oct-2026).
  ROLES_CONFIRMAN  = %w[admin supervisor].freeze

  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :paciente
  # optional: si se borra el stock, la reserva puede quedar huérfana y aún así
  # poder cancelarse/eliminarse sin romper por la FK requerida.
  belongs_to :stock, optional: true
  # Quien la cargó en la organización. Un pedido del portal no tiene: lo pidió el paciente.
  belongs_to :user, optional: true
  belongs_to :confirmada_por, class_name: 'User', optional: true
  belongs_to :dispensacion, optional: true

  # Las LÍNEAS de la reserva (15-sep-2026): un stock y una cantidad cada una, como en la
  # dispensa. `stock_id` y `cantidad` de la fila quedan con el mismo significado que en
  # `dispensaciones` —primera línea y suma— para los lectores que todavía miran la fila; lo
  # que aparta stock lee SIEMPRE las líneas.
  has_many :items, class_name: 'ReservaItem', dependent: :destroy, inverse_of: :reserva, autosave: true

  # Compatibilidad: quien construye una reserva con `stock` + `cantidad` a secas (specs, la demo,
  # la restauración) obtiene su única línea sin tener que saber que existen. También en
  # `before_create`, porque un `save(validate: false)` se saltea la validación y dejaría una
  # reserva sin líneas: apartaría cero.
  before_validation :linea_desde_la_fila, on: :create
  before_create     :linea_desde_la_fila
  before_validation :sincronizar_fila_desde_items

  validates :cantidad,               presence: true, numericality: { greater_than: 0 }
  validate  :al_menos_una_linea,     on: :create
  validates :estado,                 inclusion: { in: ESTADOS }
  validates :origen,                 inclusion: { in: ORIGENES }
  validates :user,                   presence: true, unless: :del_portal?
  validates :fecha_entrega_estimada, presence: true
  validates :sena_ars,               numericality: { greater_than_or_equal_to: 0 }

  validate :stock_pertenece_al_club, on: :create
  validate :stock_disponible,        on: :create
  validate :paciente_activo,         on: :create
  validate :fecha_entrega_futura,    on: :create

  scope :pendientes,    -> { where(estado: 'pendiente') }
  scope :solicitadas,   -> { where(estado: 'solicitada') }
  # Un pedido del portal que nadie confirmó y cuyo día ya pasó: no hay a quién entregárselo.
  scope :solicitadas_vencidas, -> { solicitadas.where('fecha_entrega_estimada < ?', Time.zone.today) }
  scope :del_paciente,  ->(paciente_id) { where(paciente_id: paciente_id) }
  scope :recientes,     -> { order(fecha_entrega_estimada: :asc, created_at: :desc) }
  # Pendientes cuya fecha de entrega ya pasó hace más de DIAS_VENCIMIENTO días.
  scope :a_vencer, lambda {
    pendientes.where('fecha_entrega_estimada < ?', Date.current - DIAS_VENCIMIENTO)
  }

  # El precio de una línea: el sugerido del stock con el descuento del paciente, como en la dispensa.
  # Lo usan la reserva de la organización, el pedido del portal y el catálogo que lo muestra.
  def self.precio_para(stock, paciente)
    descuento = paciente&.descuento_porcentaje.to_d.clamp(0, 100) / 100
    (stock.precio_sugerido_ars.to_d * (1 - descuento)).round(2)
  end

  # Los días que el paciente puede elegir para retirar lo que pide: hoy o mañana. Viaja a la pantalla
  # (`GET /portal/reservas`): la regla vive acá y nada más.
  def self.fechas_portal
    hoy = Time.zone.today
    [hoy, hoy + 1]
  end

  # UNA RESERVA POR DÍA (Germán, 28-oct-2026): puede tener una para hoy y otra para mañana, no dos para
  # el mismo día. Cuenta lo que sigue en pie ese día —esperando confirmación o confirmado—, la haya
  # pedido él o se la haya cargado la organización.
  ACTIVAS = %w[solicitada pendiente].freeze

  def self.del_dia(paciente, fecha)
    where(paciente_id: paciente.id, fecha_entrega_estimada: fecha, estado: ACTIVAS).first
  end

  # Los días para retirar, con si todavía está libre para él: [{ fecha:, etiqueta:, libre: }].
  def self.dias_portal(paciente)
    ocupados = where(paciente_id: paciente.id, estado: ACTIVAS, fecha_entrega_estimada: fechas_portal)
               .distinct.pluck(:fecha_entrega_estimada)
    fechas_portal.each_with_index.map do |f, i|
      { fecha: f.iso8601, etiqueta: i.zero? ? 'Hoy' : 'Mañana', libre: !ocupados.include?(f) }
    end
  end

  def pendiente?  = estado == 'pendiente'
  def solicitada? = estado == 'solicitada'
  def del_portal? = origen == 'portal'

  # Administración confirma el pedido del paciente: desde acá aparta como cualquier reserva. Se
  # vuelve a mirar la mesa con el candado del stock —entre el pedido y la confirmación pudo
  # dispensarse— y un día que ya pasó no se confirma.
  def confirmar!(por:)
    with_lock do
      raise ArgumentError, 'Este pedido ya no está esperando confirmación.' unless solicitada?
      raise ArgumentError, 'El día que pidió ya pasó: rechazalo y que vuelva a pedir.' if fecha_entrega_estimada < Time.zone.today

      errors.clear
      stock_disponible
      raise ArgumentError, errors.full_messages.to_sentence if errors.any?

      update!(estado: 'pendiente', confirmada_por: por, confirmada_at: Time.current)
    end
    avisar_al_paciente!
  end

  # El motivo es lo que lee el paciente: sin él, un «no» no le dice qué hacer.
  def rechazar!(por:, motivo:)
    motivo = motivo.to_s.strip
    raise ArgumentError, 'Escribí el motivo: es lo que le llega al paciente.' if motivo.blank?

    with_lock do
      raise ArgumentError, 'Este pedido ya no está esperando confirmación.' unless solicitada?

      update!(estado: 'rechazada', confirmada_por: por, rechazada_at: Time.current, motivo_rechazo: motivo)
    end
    avisar_al_paciente!
  end

  # Al paciente le cambió un pedido suyo: el portal re-pide (sin datos en el aviso) y el push
  # dice a dónde ir, sin el contenido.
  def avisar_al_paciente!
    return unless del_portal?

    ActionCable.server.broadcast(PacienteChannel.stream(paciente_id), {
      recurso: 'reservas', accion: estado, id: id, at: Time.current.iso8601(3),
    })
    return unless paciente.user

    PushNotificationService.notify_user_async(
      paciente.user,
      title: estado == 'pendiente' ? 'Tu reserva está confirmada' : 'Revisá tu pedido',
      body:  estado == 'pendiente' ? 'Tu organización confirmó lo que pediste.' : 'Tu organización no pudo confirmar tu pedido.',
      url: '/portal/reservar', tipo: 'reserva_respondida'
    )
  rescue StandardError => e
    Rails.logger.warn("[reserva] no se pudo avisar al paciente: #{e.class} #{e.message}")
  end

  # Lo que falta cobrar al entregar (total estimado menos la seña ya abonada).
  def aporte_restante_ars
    [aporte_estimado_ars.to_d - sena_ars.to_d, 0].max
  end

  # Líneas en memoria, válidas también antes de guardar (que es cuando se validan).
  def lineas
    items.reject(&:marked_for_destruction?)
  end

  # «5g de Critical Kush · 2u de OG Kush». Para los avisos: «5g» a secas no dice qué preparar.
  def descripcion_items
    lineas.map(&:descripcion).join(' · ')
  end

  # Los stocks que la reserva compromete, sin repetir.
  def stocks
    lineas.map(&:stock).compact.uniq
  end

  # También el pedido del portal que el paciente se arrepiente de haber hecho (no apartaba nada).
  def cancelar!(motivo: nil)
    return false unless pendiente? || solicitada?
    update!(estado: 'cancelada', cancelada_at: Time.current,
            notas: [notas, motivo].compact.join(' · ').presence)
  end

  def marcar_vencida!
    return false unless pendiente? || solicitada?
    update!(estado: 'vencida', vencida_at: Time.current)
  end

  private

  def linea_desde_la_fila
    return if items.any? || stock.nil? || cantidad.to_d <= 0
    items.build(stock: stock, cantidad: cantidad)
  end

  # La fila espeja las líneas: stock = primera línea, cantidad = suma. Igual que la dispensa.
  # Y al revés para el caso viejo: editar `cantidad` en una reserva de UNA línea edita esa línea
  # (`reserva.update(cantidad: 5)` sigue significando lo que significaba).
  def sincronizar_fila_desde_items
    ls = lineas
    return if ls.empty?
    if persisted? && cantidad_changed? && ls.size == 1 && !ls.first.cantidad_changed?
      ls.first.cantidad = cantidad
    end
    self.stock_id ||= ls.first.stock_id
    self.cantidad   = ls.sum { |l| l.cantidad.to_d }
  end

  def al_menos_una_linea
    errors.add(:base, 'Agregá al menos un producto a la reserva') if lineas.empty?
  end

  # Una reserva aparta stock a futuro: la entrega estimada debe ser a partir de mañana.
  # Hoy (o antes) es una dispensación directa, no una reserva.
  #
  # El pedido del portal es otra cosa (Germán, 28-oct-2026): el paciente pide para retirar HOY o
  # MAÑANA, nunca más allá —lo que hay sobre la mesa hoy no es lo que va a haber en una semana—.
  def fecha_entrega_futura
    return if fecha_entrega_estimada.blank?
    if del_portal?
      unless self.class.fechas_portal.include?(fecha_entrega_estimada)
        errors.add(:fecha_entrega_estimada, 'tiene que ser hoy o mañana')
      end
      return
    end
    if fecha_entrega_estimada <= Date.current
      errors.add(:fecha_entrega_estimada, 'debe ser a partir de mañana (una reserva para hoy es una dispensación)')
    end
  end

  def stock_pertenece_al_club
    return unless paciente
    stocks.each do |st|
      unless st.club_id == paciente.club_id || st.sede&.club_id == paciente.club_id
        errors.add(:stock, 'no pertenece a la organización')
      end
      errors.add(:stock, "«#{st.etiqueta}» no está habilitado para dispensa") if st.persisted? && !st.apto_dispensa?
    end
  end

  # Valida contra lo que NO TIENE DUEÑO: lo libre del depósito más lo libre de la mesa.
  #
  # Los dos sumandos son necesarios y ninguno alcanza solo. `cantidad_disponible_real` es el
  # depósito y ya NO incluye lo que está sobre la mesa (ver Stock#apartado_para_mesa_y_reservas):
  # sin el segundo término no se podría reservar nada de lo que se reserva, que es justamente lo
  # que está arriba. Y `libre_en_mostrador` ya descuenta las otras reservas pendientes, así que
  # dos reservas no comprometen el mismo gramo.
  #
  # Es el gemelo exacto de `Dispensacion#stock_disponible`, y por el mismo motivo: la pantalla
  # ofrece la mesa, pero el techo contra el sobregiro lo pone el backend.
  #
  # Por LÍNEA, agrupando las que repiten el mismo stock: dos renglones de 10 g del mismo frasco
  # piden 20 contra ese frasco, no 10 dos veces.
  def stock_disponible
    lineas.select(&:stock).group_by(&:stock_id).each do |_sid, ls|
      st     = ls.first.stock
      pedido = ls.sum { |l| l.cantidad.to_d }
      next if pedido <= 0
      st.with_lock do
        # El pedido del portal sale SÓLO de la mesa (es lo que el paciente vio) y no dice cuánto
        # hay: la cantidad exacta es de la operación de la organización.
        if del_portal?
          if pedido > st.libre_en_mostrador(st.sede_id)
            que = (st.genetica || st.lote&.genetica)&.nombre || Portal::DetalleDispensa::FORMAS.fetch(st.forma_producto, 'ese producto')
            errors.add(:base, "Hoy no hay tanto de «#{que}»: pedí menos o consultá por el chat.")
          end
          next
        end
        disp = st.cantidad_disponible_real.to_d + st.libre_en_mostrador(st.sede_id)
        if pedido > disp
          errors.add(:cantidad,
            "de «#{st.etiqueta}» supera el stock disponible (#{disp.round(2)} #{st.unidad || 'g'} disponibles)")
        end
      end
    end
  end

  def paciente_activo
    return unless paciente
    errors.add(:base, 'El paciente no está activo en la organización') unless paciente.es_paciente?

    # Una reserva aparta stock y termina en una entrega: si el paciente todavía no está admitido,
    # bloquear producto a su nombre es adelantarse a una decisión que no se tomó.
    return if paciente.aprobado?

    errors.add(:base, "#{paciente.nombre_completo} está pendiente de aprobación: " \
                      'no se le puede reservar producto hasta que lo apruebe un administrador o el médico.')
  end
end
