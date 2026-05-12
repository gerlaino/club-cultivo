class AriccameRegistro < ApplicationRecord
  TIPOS   = %w[entrada_producto dispensacion ajuste].freeze
  ESTADOS = %w[pendiente enviado confirmado error omitido].freeze

  belongs_to :club
  belongs_to :stock,        optional: true
  belongs_to :dispensacion, optional: true

  validates :tipo,   inclusion: { in: TIPOS }
  validates :estado, inclusion: { in: ESTADOS }

  scope :pendientes,   -> { where(estado: 'pendiente') }
  scope :con_error,    -> { where(estado: 'error') }
  scope :confirmados,  -> { where(estado: 'confirmado') }
  scope :reintentables, -> { where(estado: 'error').where('intentos < ?', 3) }

  def marcar_enviado!(codigo: nil)
    update!(estado: 'enviado', enviado_at: Time.current, codigo_ariccame: codigo, intentos: intentos + 1)
  end

  def marcar_confirmado!(codigo: nil, respuesta: {})
    update!(estado: 'confirmado', confirmado_at: Time.current, codigo_ariccame: codigo || self.codigo_ariccame, respuesta: respuesta)
  end

  def marcar_error!(mensaje:, respuesta: {})
    update!(estado: 'error', error_mensaje: mensaje, respuesta: respuesta, intentos: intentos + 1)
  end
end
