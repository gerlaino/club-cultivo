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
  ESTADOS          = %w[pendiente entregada cancelada vencida].freeze
  DIAS_VENCIMIENTO = 7 # días posteriores a la fecha de entrega estimada sin retirar → vencida

  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :paciente
  # optional: si se borra el stock, la reserva puede quedar huérfana y aún así
  # poder cancelarse/eliminarse sin romper por la FK requerida.
  belongs_to :stock, optional: true
  belongs_to :user
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
  validates :fecha_entrega_estimada, presence: true
  validates :sena_ars,               numericality: { greater_than_or_equal_to: 0 }

  validate :stock_pertenece_al_club, on: :create
  validate :stock_disponible,        on: :create
  validate :paciente_activo,         on: :create
  validate :fecha_entrega_futura,    on: :create

  scope :pendientes,    -> { where(estado: 'pendiente') }
  scope :del_paciente,  ->(paciente_id) { where(paciente_id: paciente_id) }
  scope :recientes,     -> { order(fecha_entrega_estimada: :asc, created_at: :desc) }
  # Pendientes cuya fecha de entrega ya pasó hace más de DIAS_VENCIMIENTO días.
  scope :a_vencer, lambda {
    pendientes.where('fecha_entrega_estimada < ?', Date.current - DIAS_VENCIMIENTO)
  }

  def pendiente? = estado == 'pendiente'

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

  def cancelar!(motivo: nil)
    return false unless pendiente?
    update!(estado: 'cancelada', cancelada_at: Time.current,
            notas: [notas, motivo].compact.join(' · ').presence)
  end

  def marcar_vencida!
    return false unless pendiente?
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
  def fecha_entrega_futura
    return if fecha_entrega_estimada.blank?
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
    errors.add(:base, 'El socio no está activo en la organización') unless paciente.es_paciente?

    # Una reserva aparta stock y termina en una entrega: si el paciente todavía no está admitido,
    # bloquear producto a su nombre es adelantarse a una decisión que no se tomó.
    return if paciente.aprobado?

    errors.add(:base, "#{paciente.nombre_completo} está pendiente de aprobación: " \
                      'no se le puede reservar producto hasta que lo apruebe un administrador o el médico.')
  end
end
