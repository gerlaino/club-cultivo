class WebhookDelivery < ApplicationRecord
  belongs_to :webhook

  STATUSES = %w[pending success failed].freeze

  scope :recientes, -> { order(created_at: :desc) }
  scope :fallidas,  -> { where(status: 'failed') }
end
