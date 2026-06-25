class MailEnviado < ApplicationRecord
  self.table_name = 'mails_enviados'

  belongs_to :paciente
  belongs_to :user
  belongs_to :club
  acts_as_tenant(:club)

  TIPOS = %w[bienvenida reprocann disponibilidad personalizado].freeze

  validates :asunto,        presence: true
  validates :cuerpo,        presence: true
  validates :email_destino, presence: true
  validates :tipo,          inclusion: { in: TIPOS }

  scope :recientes, -> { order(enviado_at: :desc) }
end
