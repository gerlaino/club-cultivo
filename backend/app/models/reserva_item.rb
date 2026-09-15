# Una línea de una reserva: un stock y cuánto se aparta de él. Gemela de `DispensacionItem`.
#
# No es tenant ni paranoia a propósito, igual que su gemela: vive y muere con la reserva, que
# sí es las dos cosas. Todo lo que cuente líneas apartadas filtra por el estado y el
# `deleted_at` de la RESERVA (ver `Stock#apartado_para_reservas`).
class ReservaItem < ApplicationRecord
  belongs_to :reserva, inverse_of: :items
  belongs_to :stock, optional: true # nullify si se borra el stock (igual que la dispensa)

  validates :cantidad, numericality: { greater_than: 0 }

  before_create :capturar_snapshot_trazabilidad

  # Foto del lote y la variedad al reservar: si el stock se borra después, la reserva sigue
  # diciendo qué era.
  def capturar_snapshot_trazabilidad
    self.lote_codigo     ||= stock&.lote&.codigo || stock&.lote_codigo
    self.genetica_nombre ||= (stock&.genetica || stock&.lote&.genetica)&.nombre
  end

  def subtotal_ars
    (precio_unitario_ars.to_d * cantidad.to_d).round(2)
  end

  # «5 g de Critical Kush», para los avisos y el historial.
  def descripcion
    unidad = stock&.unidad || 'g'
    que    = genetica_nombre.presence || stock&.forma_producto.to_s.humanize
    "#{cantidad.to_f}#{unidad} de #{que}"
  end
end
