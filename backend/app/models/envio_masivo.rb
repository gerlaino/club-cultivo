# Un envío masivo de correo.
#
# La regla que ordena todo esto: **un mail por destinatario, siempre**. Nunca un `To:` con
# muchas direcciones ni un BCC. Con todos juntos, cada paciente recibiría el padrón completo de
# la organización —nombre y mail de todos los demás—, que es una fuga de datos de salud
# (Ley 25.326) y no se puede deshacer. Por eso `destinatarios` es una lista y el job la recorre.
class EnvioMasivo < ApplicationRecord
  include Restorable
  self.table_name = 'envios_masivos'

  belongs_to :club
  belongs_to :user
  belongs_to :plantilla_mail, optional: true
  acts_as_tenant(:club)

  DESTINOS = %w[pacientes libre].freeze
  ESTADOS  = %w[pendiente enviando completado fallido].freeze

  validates :asunto, :cuerpo, presence: true
  validates :destino, inclusion: { in: DESTINOS }
  validates :estado,  inclusion: { in: ESTADOS }
  validate  :con_destinatarios

  scope :recientes, -> { order(created_at: :desc) }

  def en_curso? = %w[pendiente enviando].include?(estado)

  # Marca el resultado de UN destinatario. Se guarda en el acto y no al final: si el proceso se
  # cae a la mitad, lo ya enviado tiene que quedar registrado o se reenvía dos veces.
  def registrar!(email, ok:, error: nil)
    self.resultados = resultados + [{ 'email' => email, 'ok' => ok, 'error' => error }.compact]
    self.enviados += 1 if ok
    self.fallidos += 1 unless ok
    save!(validate: false)
  end

  private

  def con_destinatarios
    errors.add(:destinatarios, 'no hay a quién mandarle') if destinatarios.blank?
  end
end
