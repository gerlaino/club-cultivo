class DispensacionItem < ApplicationRecord
  include Restorable

  belongs_to :dispensacion
  belongs_to :stock, optional: true   # nullify si se borra el stock (igual que la dispensa legacy)
  # Si la línea salió de lo APARTADO para un evento del salón (el dispensador lo marcó al
  # dispensar durante el evento). Deja el rastro de qué evento consumió estos gramos.
  belongs_to :evento_bar, optional: true

  validates :cantidad, numericality: { greater_than: 0 }

  before_create :capturar_snapshot_trazabilidad

  # Snapshot inmutable de trazabilidad de la línea: copia código de lote y genética de su stock
  # al crear, para sobrevivir aunque el stock se elimine después (stock_id queda en nullify).
  def capturar_snapshot_trazabilidad
    self.lote_codigo     ||= stock&.lote&.codigo || stock&.lote_codigo
    self.genetica_nombre ||= (stock&.genetica || stock&.lote&.genetica)&.nombre
  end

  # Subtotal de la línea (precio unitario × cantidad). Si no hay precio cargado, 0.
  def subtotal_ars
    (precio_unitario_ars.to_d * cantidad.to_d).round(2)
  end

  # Costo total de la línea (para contabilidad/márgenes).
  def costo_total_ars
    (costo_unitario_ars.to_d * cantidad.to_d).round(2)
  end
end
