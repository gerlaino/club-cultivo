# Plantilla de correo de UNA organización, escrita por su admin.
#
# El punto delicado es el renderizado. El cuerpo es texto que escribe un usuario, así que
# resolverlo con ERB —o con cualquier cosa que evalúe código— sería ejecución remota en el
# servidor: `<%= User.first %>` en el cuerpo de un mail. Por eso las variables se resuelven con
# `gsub` contra una lista blanca cerrada: lo que no está en VARIABLES queda tal cual se escribió.
class PlantillaMail < ApplicationRecord
  include Restorable
  self.table_name = 'plantillas_mail'

  belongs_to :club
  belongs_to :creada_por, class_name: 'User', optional: true
  has_many   :mails_enviados, dependent: :nullify

  acts_as_tenant(:club)

  validates :nombre, presence: true, length: { maximum: 60 }
  validates :asunto, presence: true, length: { maximum: 200 }
  validates :cuerpo, presence: true
  validates :nombre, uniqueness: { scope: :club_id, case_sensitive: false,
                                   conditions: -> { where(deleted_at: nil) },
                                   message: 'ya está usado por otra plantilla' }
  validate  :una_sola_bienvenida

  scope :activas,    -> { where(activa: true) }
  scope :ordenadas,  -> { order(bienvenida: :desc, nombre: :asc) }

  # Lo único que se interpola. La clave es lo que el admin escribe entre llaves; el valor, cómo
  # se resuelve. Agregar una variable acá es la ÚNICA forma de que exista.
  VARIABLES = {
    'nombre'                => ->(p, _club) { p&.nombre.to_s.strip },
    'apellido'              => ->(p, _club) { p&.apellido.to_s.strip },
    'nombre_completo'       => ->(p, _club) { [p&.nombre, p&.apellido].compact_blank.join(' ') },
    'organizacion'          => ->(_p, club) { club&.name.to_s },
    'reprocann_numero'      => ->(p, _club) { p&.reprocann_numero.to_s },
    'reprocann_vencimiento' => ->(p, _club) { fecha(p&.reprocann_vencimiento) },
  }.freeze

  # Para mostrarle al admin qué puede escribir, con un ejemplo de qué sale.
  VARIABLES_AYUDA = {
    'nombre'                => 'Nombre de pila del paciente',
    'apellido'              => 'Apellido del paciente',
    'nombre_completo'       => 'Nombre y apellido',
    'organizacion'          => 'Nombre de la organización',
    'reprocann_numero'      => 'Número de REPROCANN, si lo tiene',
    'reprocann_vencimiento' => 'Fecha de vencimiento del REPROCANN',
  }.freeze

  def self.fecha(d)
    return '' if d.blank?
    d.to_date.strftime('%d/%m/%Y')
  rescue Date::Error
    ''
  end

  # Reemplaza `{{variable}}` por su valor. Tolera espacios (`{{ nombre }}`) porque el admin los
  # escribe naturalmente, y deja intacto lo que no reconoce: si alguien escribe `{{telefono}}`
  # ve el literal en la vista previa y entiende que esa variable no existe, en vez de recibir un
  # mail con un hueco silencioso.
  def self.render(texto, paciente:, club:)
    texto.to_s.gsub(/\{\{\s*([a-z_]+)\s*\}\}/) do
      resolver = VARIABLES[Regexp.last_match(1)]
      resolver ? resolver.call(paciente, club).to_s : Regexp.last_match(0)
    end
  end

  def asunto_para(paciente) = self.class.render(asunto, paciente: paciente, club: club)
  def cuerpo_para(paciente) = self.class.render(cuerpo, paciente: paciente, club: club)

  # Las cuatro que estaban hardcodeadas en el frontend. Se siembran la primera vez que la
  # organización abre la pantalla, así el día uno no cambia nada pero pasan a ser suyas.
  SEMILLA = [
    {
      nombre: 'Bienvenida', bienvenida: true,
      asunto: 'Bienvenido/a a {{organizacion}}',
      cuerpo: "Hola {{nombre}},\n\nTe damos la bienvenida como paciente de nuestra organización.\n\nEstamos a tu disposición para cualquier consulta.\n\nSaludos,",
    },
    {
      nombre: 'Renovación de REPROCANN',
      asunto: 'Renovación de REPROCANN — {{nombre_completo}}',
      cuerpo: "Hola {{nombre}},\n\nTe recordamos que tu habilitación REPROCANN vence el {{reprocann_vencimiento}}.\n\nPor favor comunicate con nosotros para gestionar la renovación antes de esa fecha.\n\nSaludos,",
    },
    {
      nombre: 'Aviso de disponibilidad',
      asunto: 'Aviso de disponibilidad — {{nombre_completo}}',
      cuerpo: "Hola {{nombre}},\n\nTe informamos que hay producto disponible para tu retiro.\n\nPodés pasar a retirar en los horarios habituales. Ante cualquier duda no dudes en contactarnos.\n\nSaludos,",
    },
  ].freeze

  # Idempotente por nombre: si el admin borró una de las semillas, no se la devolvemos.
  def self.sembrar!(club)
    return if exists?(club_id: club.id)

    SEMILLA.each { |attrs| create!(attrs.merge(club: club)) }
  end

  private

  # El índice único de la base es la barrera real; esto es para devolver un error legible en vez
  # de un RecordNotUnique.
  def una_sola_bienvenida
    return unless bienvenida? && deleted_at.nil?

    otra = self.class.where(club_id: club_id, bienvenida: true, deleted_at: nil).where.not(id: id)
    return unless otra.exists?

    errors.add(:bienvenida, 'ya hay otra plantilla marcada como la de bienvenida')
  end
end
