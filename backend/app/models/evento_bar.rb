# Un evento de un bar (fiesta, cata, taller): un proyecto con P&L propio. El resultado real se
# arma desde el libro contable (movimientos etiquetados con evento_bar_id). Los costos/proveedores
# y las ventas de barra atribuidas al evento son las fuentes. Recuperable desde la papelera.
class EventoBar < ApplicationRecord
  include Restorable
  acts_as_tenant(:club)

  self.table_name = 'eventos_bar'

  belongs_to :club
  belongs_to :bar
  has_many :costos,  class_name: 'EventoBarCosto', foreign_key: :evento_bar_id, dependent: :destroy
  has_many :tareas,  class_name: 'EventoBarTarea', foreign_key: :evento_bar_id, dependent: :destroy
  has_many :movimientos_contables, foreign_key: :evento_bar_id, dependent: :nullify
  has_many :bar_ventas,            foreign_key: :evento_bar_id, dependent: :nullify

  ESTADOS = %w[planificado en_venta en_curso finalizado cancelado].freeze

  validates :nombre, presence: true
  validates :estado, inclusion: { in: ESTADOS }
  validates :presupuesto_ingresos, numericality: { greater_than_or_equal_to: 0 }

  scope :proximos, -> { where('fecha >= ? OR fecha IS NULL', Date.current).order(Arel.sql('fecha IS NULL, fecha ASC')) }
  scope :pasados,  -> { where('fecha < ?', Date.current).order(fecha: :desc) }

  # P&L real: ingresos − egresos del libro etiquetados con este evento.
  def resultado
    ingresos = movimientos_contables.where(tipo: %w[ingreso recupero_costo]).sum(:monto_ars)
    egresos  = movimientos_contables.where(tipo: 'egreso').sum(:monto_ars)
    { ingresos: ingresos.to_f, egresos: egresos.to_f, resultado: (ingresos - egresos).to_f }
  end

  # Presupuesto: ingresos estimados y egresos comprometidos (suma de costos, pagados o no).
  def costos_comprometidos = costos.sum(:monto_ars).to_f
  def costos_pagados       = costos.where(pagado: true).sum(:monto_ars).to_f

  # Resultado proyectado: lo estimado de ingresos menos lo comprometido en costos.
  def resultado_proyectado
    (presupuesto_ingresos.to_d - costos.sum(:monto_ars).to_d).to_f
  end
end
