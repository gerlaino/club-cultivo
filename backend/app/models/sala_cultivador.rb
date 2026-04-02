class SalaCultivador < ApplicationRecord
  self.table_name = 'sala_cultivadores'

  belongs_to :sala
  belongs_to :user

  validates :sala_id, uniqueness: { scope: :user_id }
  validate :user_must_be_cultivador

  private

  def user_must_be_cultivador
    errors.add(:user, 'debe ser cultivador') unless user&.cultivador?
  end
end