class CuentaCorriente < ApplicationRecord
  belongs_to :paciente
  belongs_to :club

  has_many :movimientos, class_name: 'CuentaCorrienteMovimiento', dependent: :destroy

  validates :limite_credito,   numericality: { greater_than_or_equal_to: 0 }
  validates :saldo_disponible, numericality: {}

  def tiene_credito?
    limite_credito.to_f > 0
  end

  def puede_dispensar?(monto)
    (saldo_disponible.to_d + limite_credito.to_d) >= monto.to_d
  end

  def puede_dispensar_g?(gramos)
    credito_gramos_activo? && saldo_disponible_g.to_d >= gramos.to_d
  end

  def porcentaje_consumido
    return 0 if limite_credito.to_f.zero?
    consumido = limite_credito.to_f - saldo_disponible.to_f
    [(consumido / limite_credito.to_f * 100).round(1), 100].min
  end
end
