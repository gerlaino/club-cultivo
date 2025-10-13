class Club < ApplicationRecord
  has_many :users, dependent: :restrict_with_error

  has_one_attached :logo

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
