class PatientDocument < ApplicationRecord
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :paciente
  belongs_to :template, class_name: 'DocumentTemplate', optional: true
  belongs_to :created_by, class_name: 'User'

  # Cifrado at-rest: documento clínico + DNI de las firmas (Ley 25.326 art. 9 / Res. 47/2018).
  encrypts :contenido_html
  encrypts :firma_paciente_dni
  encrypts :firma_medico_dni

  has_one_attached :archivo_pdf

  ESTADOS = %w[borrador pendiente_firma firmado archivado].freeze

  ESTADO_LABELS = {
    'borrador'         => 'Borrador',
    'pendiente_firma'  => 'Pendiente de firma',
    'firmado'          => 'Firmado',
    'archivado'        => 'Archivado',
  }.freeze

  validates :nombre,          presence: true
  validates :tipo,            presence: true
  validates :estado,          inclusion: { in: ESTADOS }
  validates :contenido_html, presence: true, unless: -> { archivo_pdf.attached? || archivo_pdf.attachment.present? }

  scope :for_club,  ->(club_id) { where(club_id: club_id) }
  scope :for_paciente, ->(paciente_id) { where(paciente_id: paciente_id) }
  scope :firmados,  -> { where(estado: 'firmado') }

  before_create :calcular_hash

  def firmado_completamente?
    firmado_paciente_at.present? && firmado_medico_at.present?
  end

  def estado_label
    ESTADO_LABELS[estado] || estado
  end

  # Interpola variables en el contenido HTML con datos reales
  def self.interpolar(html, paciente:, club:, medico: nil)
    vars = {
      '{{paciente_nombre}}'          => paciente.nombre,
      '{{paciente_apellido}}'        => paciente.apellido,
      '{{paciente_dni}}'             => paciente.dni,
      '{{paciente_fecha_nacimiento}}' => paciente.fecha_nacimiento&.strftime('%d/%m/%Y'),
      '{{paciente_reprocann}}'       => paciente.reprocann_numero || '—',
      '{{club_nombre}}'              => club.name,
      '{{club_legal_name}}'          => club.legal_name || club.name,
      '{{club_direccion}}'           => [club.address, club.city, club.state].compact.join(', '),
      '{{medico_nombre}}'            => medico ? "#{medico.first_name} #{medico.last_name}".strip : '—',
      '{{medico_dni}}'               => medico&.dni || '—',
      '{{fecha_hoy}}'                => Date.today.strftime('%d/%m/%Y'),
      '{{fecha_hoy_largo}}' => Date.today.strftime('%d de %B de %Y'),
    }
    vars.reduce(html) { |html, (var, val)| html.gsub(var, val.to_s) }
  end

  private

  def calcular_hash
    return unless contenido_html.present?
    self.hash_documento = Digest::SHA256.hexdigest(contenido_html)
  end
end
