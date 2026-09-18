# Una dirección de entrega del paciente, con nombre («Trabajo») y, como mucho una por paciente,
# por defecto: la que el modal de dispensa preselecciona. El domicilio REPROCANN no es una de
# éstas —vive en la ficha, es del trámite— pero se ofrece al lado al elegir a dónde va el paquete.
class DireccionPaciente < ApplicationRecord
  self.table_name = 'direcciones_pacientes'

  belongs_to :paciente
  belongs_to :club
  acts_as_tenant(:club)

  validates :calle, presence: true
  validates :etiqueta, length: { maximum: 60 }

  scope :ordenadas, -> { order(por_defecto: :desc, created_at: :asc) }

  # Una sola por defecto por paciente: marcar ésta desmarca las demás.
  before_save :desmarcar_las_otras, if: -> { por_defecto? && (por_defecto_changed? || new_record?) }
  # La primera que se carga es la por defecto: sin eso el modal no tendría qué preseleccionar.
  before_validation :ser_la_primera, on: :create

  CAMPOS = %i[calle altura piso depto barrio ciudad].freeze

  def campos = CAMPOS.to_h { |c| [c, public_send(c)] }
  def texto  = Paciente.direccion_texto(campos)

  def como_json
    { id: id, etiqueta: etiqueta, texto: texto, por_defecto: por_defecto, **campos }
  end

  private

  def desmarcar_las_otras
    DireccionPaciente.where(paciente_id: paciente_id, por_defecto: true).where.not(id: id).update_all(por_defecto: false)
  end

  def ser_la_primera
    self.por_defecto = true unless DireccionPaciente.where(paciente_id: paciente_id).exists?
  end
end
