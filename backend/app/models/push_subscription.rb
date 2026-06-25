class PushSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :club
  acts_as_tenant(:club)

  validates :endpoint,   presence: true, uniqueness: true
  validates :p256dh_key, presence: true
  validates :auth_key,   presence: true

  scope :active, -> { where(active: true) }
end
