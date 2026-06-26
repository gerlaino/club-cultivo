class CuentaCorrienteMovimiento < ApplicationRecord
  include Restorable
  belongs_to :cuenta_corriente
  belongs_to :dispensacion, optional: true
  belongs_to :created_by, class_name: 'User'

  TIPOS = %w[carga debito ajuste pago].freeze
  TIPO_LABELS = {
    'carga'  => 'Carga de crédito',
    'debito' => 'Débito dispensación',
    'ajuste' => 'Ajuste manual',
    'pago'   => 'Pago de saldo',
  }.freeze

  validates :tipo, inclusion: { in: TIPOS }
  validates :monto, :saldo_anterior, :saldo_nuevo, numericality: true

  scope :recientes, -> { order(created_at: :desc) }

  def tipo_label
    TIPO_LABELS[tipo] || tipo
  end

  def es_carga?
    %w[carga ajuste pago].include?(tipo) && monto.to_f > 0
  end
end
