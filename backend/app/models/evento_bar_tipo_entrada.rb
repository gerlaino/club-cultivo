# Un tipo de entrada de un evento (Early bird, General, VIP…). El ingreso se agrega en el libro:
# un movimiento por tipo, con monto = vendidas * precio, actualizado en cada venta/anulación.
class EventoBarTipoEntrada < ApplicationRecord
  include Restorable
  acts_as_tenant(:club)

  self.table_name = 'evento_bar_tipos_entrada'

  belongs_to :club
  belongs_to :evento_bar
  belongs_to :movimiento_contable, optional: true
  has_many :entradas, class_name: 'EventoBarEntrada', foreign_key: :evento_bar_tipo_entrada_id, dependent: :destroy

  validates :nombre, presence: true
  validates :precio_ars, numericality: { greater_than_or_equal_to: 0 }
  validates :cupo, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :activos,   -> { where(activo: true) }
  scope :ordenados, -> { order(:orden, :created_at) }

  def vendidas    = entradas.where(estado: %w[valida usada]).count
  def disponibles = cupo ? [cupo - vendidas, 0].max : nil
  def agotado?    = cupo.present? && vendidas >= cupo
  def recaudado   = (vendidas * precio_ars.to_d).to_f

  # Ingreso agregado del tipo en el libro (vendidas * precio). Idempotente: crea, actualiza o
  # saca el movimiento según la cantidad vendida. Re-usable al restaurar desde la papelera.
  def sincronizar_ingreso!(actor)
    monto = vendidas * precio_ars.to_d
    if monto.positive?
      if movimiento_contable.nil?
        bar = evento_bar.bar
        mov = club.movimientos_contables.create!(
          created_by: actor, tipo: 'ingreso', categoria: 'bar',
          unidad_negocio: bar&.unidad_negocio_bar, sede_id: bar&.sede_id, evento_bar_id: evento_bar_id,
          descripcion: "Entradas #{nombre} — #{evento_bar.nombre}", monto_ars: monto,
          fecha: Date.current, pagado: true, medio_pago: 'efectivo'
        )
        update_column(:movimiento_contable_id, mov.id)
      elsif movimiento_contable.monto_ars.to_d != monto
        movimiento_contable.update!(monto_ars: monto)
      end
    elsif movimiento_contable.present?
      m = movimiento_contable
      update_column(:movimiento_contable_id, nil)
      m.destroy
    end
  end
end
