class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist

  self.table_name = 'jwt_denylists'

  scope :expired, -> { where('created_at < ?', 12.hours.ago) }
end
