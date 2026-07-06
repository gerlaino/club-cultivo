# Una compra financiada en cuotas mensuales (ej: un aire acondicionado en 6 cuotas con la
# tarjeta del club). Al crearse genera N MovimientoContable (egresos), uno por mes desde
# `fecha_primera_cuota`, para que cada cuota impacte el balance del mes que corresponde.
# Se puede backdatear la primera cuota para cuadrar meses anteriores.
class CompraCuotas < ApplicationRecord
  self.table_name = 'compras_cuotas'

  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :sede
  belongs_to :created_by, class_name: 'User'
  has_many   :movimientos_contables, class_name: 'MovimientoContable',
             foreign_key: :compra_cuotas_id, dependent: :destroy  # las cuotas generadas

  validates :descripcion,         presence: true
  validates :categoria,           presence: true, inclusion: { in: MovimientoContable::CATEGORIAS_EGRESO }
  validates :monto_total_ars,     presence: true, numericality: { greater_than: 0 }
  validates :cuotas_total,        presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 120 }
  validates :fecha_primera_cuota, presence: true

  after_create :generar_cuotas!

  # Edita la compra y REGENERA las cuotas desde cero (borra los movimientos viejos y crea los
  # nuevos con el total/cantidad actualizados). Atómico. Devuelve true/false (errores en el
  # record). El guard de período cerrado se valida en el controller antes de llamar.
  def actualizar_y_regenerar!(attrs)
    transaction do
      update!(attrs)
      movimientos_contables.destroy_all
      generar_cuotas!
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # El total se reparte en cuotas iguales; la última absorbe el redondeo para que sumen
  # exacto. Cada cuota queda fechada en su mes (cuota i → primera_cuota + (i-1) meses).
  def generar_cuotas!
    base = (monto_total_ars / cuotas_total).round(2)
    (1..cuotas_total).each do |i|
      fecha = fecha_primera_cuota >> (i - 1)
      monto = i == cuotas_total ? (monto_total_ars - base * (cuotas_total - 1)) : base
      movimientos_contables.create!(
        club:        club,
        sede:        sede,
        created_by:  created_by,
        tipo:        'egreso',
        categoria:   categoria,
        descripcion: "#{descripcion} — cuota #{i}/#{cuotas_total}",
        monto_ars:   monto,
        fecha:       fecha,
        medio_pago:  medio_pago,
        proveedor:   proveedor,
        cuota_numero: i,
        pagado:      fecha <= Date.current,  # cuotas pasadas: pagadas; futuras: pendientes (zona del club)
        # Se refleja quién pagó (tarjeta/responsable) en cada cuota para que sea visible.
        notas:       [("Pago: #{responsable}" if responsable.present?), notas].compact.join(' · ').presence,
      )
    end
  end
end
