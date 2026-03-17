# backend/app/models/document_template.rb
class DocumentTemplate < ApplicationRecord
  belongs_to :club
  belongs_to :created_by, class_name: 'User'
  has_many   :patient_documents, foreign_key: :template_id, dependent: :nullify

  TIPOS = %w[
    consentimiento_informado
    indicacion_medica
    declaracion_jurada
    informe_semestral
    carnet_vinculacion
    otro
  ].freeze

  TIPO_LABELS = {
    'consentimiento_informado' => 'Consentimiento Informado Bilateral',
    'indicacion_medica'        => 'Indicación Médica',
    'declaracion_jurada'       => 'Declaración Jurada',
    'informe_semestral'        => 'Informe Semestral',
    'carnet_vinculacion'       => 'Carnet de Vinculación',
    'otro'                     => 'Otro',
  }.freeze

  # Variables disponibles para interpolación
  VARIABLES_DISPONIBLES = %w[
    {{paciente_nombre}} {{paciente_apellido}} {{paciente_dni}}
    {{paciente_fecha_nacimiento}} {{paciente_reprocann}}
    {{club_nombre}} {{club_legal_name}} {{club_direccion}}
    {{medico_nombre}} {{medico_dni}}
    {{fecha_hoy}} {{fecha_hoy_largo}}
  ].freeze

  validates :nombre, presence: true
  validates :tipo,   inclusion: { in: TIPOS }
  validates :contenido_html, presence: true

  scope :activos, -> { where(activo: true) }
  scope :por_tipo, ->(tipo) { where(tipo: tipo) }

  def tipo_label
    TIPO_LABELS[tipo] || tipo
  end
end