class SocioNotum < ApplicationRecord
  belongs_to :paciente, foreign_key: :paciente_id
  belongs_to :user
end
