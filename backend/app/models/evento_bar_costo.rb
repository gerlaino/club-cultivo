# Un costo/proveedor de un evento (DJ, sonido, seguridad…). Cuando está pagado, genera el egreso
# en el libro contable, etiquetado con el evento, la sede del bar y la unidad "Bar". Si se despaga
# o se borra, el egreso se saca. Así el P&L del evento y del club quedan siempre consistentes.
class EventoBarCosto < ApplicationRecord
  include Restorable
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :evento_bar
  belongs_to :movimiento_contable, optional: true
  belongs_to :created_by, class_name: 'User'

  validates :concepto, presence: true
  validates :monto_ars, numericality: { greater_than: 0 }

  after_save     :sincronizar_egreso
  before_destroy :borrar_egreso, prepend: true

  # Idempotente: crea el egreso si está pagado y falta, lo actualiza si cambió el monto, o lo
  # saca si dejó de estar pagado. Se puede invocar de nuevo al restaurar desde la papelera.
  def sincronizar_egreso
    if pagado?
      if movimiento_contable.nil? || movimiento_contable.deleted_at.present?
        crear_egreso!
      elsif movimiento_contable.monto_ars.to_d != monto_ars.to_d
        movimiento_contable.update!(monto_ars: monto_ars, descripcion: descripcion_egreso)
      end
    elsif movimiento_contable.present?
      borrar_egreso
    end
  end

  private

  def crear_egreso!
    bar    = evento_bar.bar
    unidad = bar&.unidad_negocio_bar
    mov = club.movimientos_contables.create!(
      created_by: created_by, tipo: 'egreso',
      categoria: 'otro', unidad_negocio: unidad, sede_id: bar&.sede_id,
      evento_bar_id: evento_bar_id,
      descripcion: descripcion_egreso,
      monto_ars: monto_ars, fecha: fecha || Date.current,
      proveedor: proveedor, pagado: true, medio_pago: 'efectivo'
    )
    update_column(:movimiento_contable_id, mov.id)
  end

  def borrar_egreso
    return if movimiento_contable.nil?

    m = movimiento_contable
    update_column(:movimiento_contable_id, nil)
    m.destroy
  end

  def descripcion_egreso
    "Evento #{evento_bar.nombre} — #{concepto}#{proveedor.present? ? " (#{proveedor})" : ''}"
  end
end
