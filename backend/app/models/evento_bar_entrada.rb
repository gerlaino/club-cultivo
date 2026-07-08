# Una entrada individual vendida de un evento. Lleva un código único para el QR (Capa 4) y
# un estado (valida → usada al hacer check-in; anulada si se devuelve). El ingreso lo agrega
# el tipo de entrada, no cada entrada.
class EventoBarEntrada < ApplicationRecord
  include Restorable
  acts_as_tenant(:club)

  self.table_name = 'evento_bar_entradas'

  belongs_to :club
  belongs_to :evento_bar
  belongs_to :evento_bar_tipo_entrada
  belongs_to :created_by, class_name: 'User'

  ESTADOS = %w[valida usada anulada].freeze

  validates :codigo, presence: true, uniqueness: true
  validates :precio_ars, numericality: { greater_than_or_equal_to: 0 }
  validates :estado, inclusion: { in: ESTADOS }

  before_validation :generar_codigo, on: :create

  scope :vigentes, -> { where(estado: %w[valida usada]) }

  private

  def generar_codigo
    self.codigo ||= SecureRandom.hex(8)
  end
end
