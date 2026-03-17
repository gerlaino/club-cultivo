class PatientDocument < ApplicationRecord
  belongs_to :club
  belongs_to :socio
  belongs_to :template, class_name: 'DocumentTemplate', optional: true
  belongs_to :created_by, class_name: 'User'

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
  validates :contenido_html,  presence: true

  scope :for_club,  ->(club_id) { where(club_id: club_id) }
  scope :for_socio, ->(socio_id) { where(socio_id: socio_id) }
  scope :firmados,  -> { where(estado: 'firmado') }

  before_create :calcular_hash

  def firmado_completamente?
    firmado_paciente_at.present? && firmado_medico_at.present?
  end

  def estado_label
    ESTADO_LABELS[estado] || estado
  end

  # Interpola variables en el contenido HTML con datos reales
  def self.interpolar(html, socio:, club:, medico: nil)
    vars = {
      '{{paciente_nombre}}'          => socio.nombre,
      '{{paciente_apellido}}'        => socio.apellido,
      '{{paciente_dni}}'             => socio.dni,
      '{{paciente_fecha_nacimiento}}' => socio.fecha_nacimiento&.strftime('%d/%m/%Y'),
      '{{paciente_reprocann}}'       => socio.reprocann_numero || '—',
      '{{club_nombre}}'              => club.name,
      '{{club_legal_name}}'          => club.legal_name || club.name,
      '{{club_direccion}}'           => [club.address, club.city, club.state].compact.join(', '),
      '{{medico_nombre}}'            => medico ? "#{medico.first_name} #{medico.last_name}".strip : '—',
      '{{medico_dni}}'               => medico&.dni || '—',
      '{{fecha_hoy}}'                => Date.today.strftime('%d/%m/%Y'),
      '{{fecha_hoy_largo}}'          => I18n.l(Date.today, format: :long) rescue Date.today.strftime('%d de %B de %Y'),
    }
    vars.reduce(html) { |html, (var, val)| html.gsub(var, val.to_s) }
  end

  private

  def calcular_hash
    return unless contenido_html.present?
    self.hash_documento = Digest::SHA256.hexdigest(contenido_html)
  end
end
