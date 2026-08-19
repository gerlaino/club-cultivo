class MailEnviado < ApplicationRecord
  include Restorable
  self.table_name = 'mails_enviados'

  belongs_to :paciente
  belongs_to :user
  belongs_to :club
  # Con qué plantilla salió. Opcional: los mails libres no usan ninguna, y los enviados antes de
  # que las plantillas fueran editables tampoco tienen.
  belongs_to :plantilla_mail, optional: true
  acts_as_tenant(:club)

  TIPOS = %w[bienvenida reprocann disponibilidad personalizado acceso_portal].freeze

  validates :asunto,        presence: true
  validates :cuerpo,        presence: true
  validates :email_destino, presence: true
  validates :tipo,          inclusion: { in: TIPOS }

  scope :recientes, -> { order(enviado_at: :desc) }
end
