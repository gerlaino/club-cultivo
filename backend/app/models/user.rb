class User < ApplicationRecord
  belongs_to :club, optional: false
  devise :database_authenticatable, :recoverable, :rememberable, :validatable
  enum :role, { super_admin: "super_admin", admin: "admin", medico: "medico", cultivador: "cultivador" }, prefix: true
  validates :role, presence: true
end
