class UserSede < ApplicationRecord
  self.table_name = 'user_sedes'
  belongs_to :user
  belongs_to :sede
  validates :sede_id, uniqueness: { scope: :user_id }
end