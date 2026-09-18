class CuentaCorriente < ApplicationRecord
  include Restorable
  belongs_to :paciente
  belongs_to :club
  acts_as_tenant(:club)

  has_many :movimientos, class_name: 'CuentaCorrienteMovimiento', dependent: :destroy

  validates :limite_credito,   numericality: { greater_than_or_equal_to: 0 }
  validates :saldo_disponible, numericality: {}

  # ¿Puede DEBER? Lo habilita el admin por paciente. Es distinto de tener saldo a favor, que
  # desde sep-2026 puede tener cualquiera (todo paciente nace con cuenta corriente).
  def tiene_credito?
    limite_credito.to_f > 0
  end

  # Lo que tiene A FAVOR (saldo positivo); cero si debe.
  def saldo_a_favor
    [saldo_disponible.to_d, 0.to_d].max
  end

  # ¿Dice algo? Una cuenta en cero, sin crédito y sin historia es la que nace con el paciente y
  # nadie usó todavía: no hay nada que mostrarle.
  def en_uso?
    tiene_credito? || saldo_disponible.to_d != 0 || movimientos.exists?
  end

  def puede_dispensar?(monto)
    (saldo_disponible.to_d + limite_credito.to_d) >= monto.to_d
  end

  def porcentaje_consumido
    return 0 if limite_credito.to_f.zero?
    # saldo_disponible starts at 0 and goes negative as credit is used.
    # Amount owed = how far into the negative the saldo has gone.
    owed = [(-saldo_disponible.to_f), 0].max
    [(owed / limite_credito.to_f * 100).round(1), 100].min
  end
end
