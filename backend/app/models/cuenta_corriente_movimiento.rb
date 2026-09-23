class CuentaCorrienteMovimiento < ApplicationRecord
  include Restorable
  belongs_to :cuenta_corriente
  belongs_to :dispensacion, optional: true
  belongs_to :created_by, class_name: 'User'

  # `a_favor`: lo que el paciente había pagado por un paquete que no se le pudo entregar; la plata
  # ya entró (su ingreso queda en el libro), así que no lleva asiento — como el excedente.
  # `devolucion`: plata a favor que administración le devolvió (`CuentasCorrientes::DevolverSaldo`).
  TIPOS = %w[carga debito ajuste pago a_favor devolucion].freeze
  TIPO_LABELS = {
    'carga'      => 'Carga de crédito',
    'debito'     => 'Débito dispensación',
    'ajuste'     => 'Ajuste manual',
    'pago'       => 'Pago de saldo',
    'a_favor'    => 'Queda a favor',
    'devolucion' => 'Devolución',
  }.freeze

  validates :tipo, inclusion: { in: TIPOS }
  validates :monto, :saldo_anterior, :saldo_nuevo, numericality: true

  scope :recientes, -> { order(created_at: :desc) }

  def tipo_label
    TIPO_LABELS[tipo] || tipo
  end

  def es_carga?
    %w[carga ajuste pago a_favor].include?(tipo) && monto.to_f > 0
  end
end
