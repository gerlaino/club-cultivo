class CheckIn < ApplicationRecord
  belongs_to :paciente
  belongs_to :dispensacion, optional: true
  belongs_to :club

  VIAS = %w[dispensacion medico autoregistro].freeze

  validates :via_registro, inclusion: { in: VIAS }
  validates :escala_bienestar, numericality: { only_integer: true, in: 1..10 }, allow_nil: true

  def quimiotipo_label
    s = sintomas || {}
    { dolor: s['dolor'], sueno: s['sueno'], ansiedad: s['ansiedad'], humor: s['humor'] }
  end
end
