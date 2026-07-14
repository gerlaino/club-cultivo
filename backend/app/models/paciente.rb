class Paciente < ApplicationRecord
  include RestorableInterface
  acts_as_paranoid
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User", optional: true
  belongs_to :deleted_by, class_name: "User", optional: true

  has_many :notas, class_name: "PacienteNota", dependent: :destroy
  has_many :indicacion_medicas, dependent: :destroy
  has_many :dispensaciones, class_name: 'Dispensacion', dependent: :destroy
  has_many :resenas, class_name: 'ResenaProducto', dependent: :destroy
  has_many :reservas, dependent: :destroy
  has_many :patient_documents, dependent: :destroy
  has_one  :cuenta_corriente, dependent: :destroy
  has_many :reprocann_renovaciones, class_name: 'ReprocannRenovacion', dependent: :destroy
  has_many :mails_enviados, class_name: 'MailEnviado', dependent: :destroy
  has_many :check_ins, dependent: :destroy
  has_many :turnos, dependent: :destroy

  has_one_attached :reprocann_documento

  # ==> Cifrado at-rest de datos sensibles (Ley 25.326 art. 9 / Res. AAIP 47/2018).
  # Determinístico donde hace falta igualdad/uniqueness/búsqueda exacta; no-determinístico
  # (más seguro) en el resto. nombre/apellido y domicilio_* quedan en claro a propósito:
  # se usan en búsquedas LIKE / lógica de envíos (ver ENC-01b en SECURITY_AUDIT.md).
  encrypts :dni,              deterministic: true
  encrypts :dni_normalizado, deterministic: true
  encrypts :reprocann_numero, deterministic: true
  encrypts :email
  encrypts :telefono
  encrypts :notas_clinicas
  encrypts :motivo_consulta
  encrypts :anamnesis
  encrypts :antecedentes_personales
  encrypts :antecedentes_familiares
  encrypts :diagnostico_principal
  encrypts :diagnostico_secundario
  encrypts :evolucion_clinica
  encrypts :alergias
  encrypts :medicacion_habitual
  encrypts :grupo_sanguineo

  before_validation :normalize_dni!
  before_create     :assign_carnet_token
  after_create_commit :dispatch_webhook

  validates :nombre, :apellido, :dni, :dni_normalizado, :fecha_nacimiento, presence: true
  # Unicidad global (no por club) — requisito REPROCANN: un DNI no puede estar en dos clubes a la vez.
  validates :dni_normalizado,
    uniqueness: { message: "ya está registrado en el sistema. Bajo REPROCANN, un DNI no puede pertenecer a dos clubes simultáneamente." },
    format:     { with: /\A\d{7,9}\z/, message: "debe tener 7 a 9 dígitos" }
  validate :fecha_nacimiento_pasada

  scope :for_club,          ->(club_id) { where(club_id: club_id) }
  scope :con_seguimiento,   -> { where(con_seguimiento_medico: true) }
  scope :sin_seguimiento,   -> { where(con_seguimiento_medico: false) }

  scope :reprocann_por_vencer, -> {
    where('reprocann_vencimiento IS NOT NULL')
      .where('reprocann_vencimiento <= ?', 30.days.from_now)
      .where('reprocann_vencimiento >= ?', Date.today)
  }

  def nombre_completo
    "#{nombre} #{apellido}"
  end

  # Dirección de entrega efectiva: la de envío si el paciente la cargó (envio_calle),
  # si no, su domicilio. Se usa como snapshot al dispensar/reservar con envío.
  def direccion_entrega
    if envio_calle.present?
      { calle: envio_calle, altura: envio_altura, piso: envio_piso, depto: envio_depto, barrio: envio_barrio, ciudad: envio_ciudad }
    else
      { calle: domicilio_calle, altura: domicilio_altura, piso: domicilio_piso, depto: domicilio_depto, barrio: domicilio_barrio, ciudad: domicilio_ciudad }
    end
  end

  # Estado REPROCANN cruzado con la fecha: el campo manual puede quedar en
  # "activo" después de vencer — para mostrar, la fecha manda sobre el campo.
  # Estado a mostrar, cruzado con la fecha:
  # - 'activo' cuya fecha ya pasó → 'vencido' (rojo): cert aprobado que caducó.
  # - 'pendiente' NO se pisa aunque la fecha esté vencida: significa que hay un
  #   trámite de renovación en curso (se muestra ámbar, no rojo).
  def reprocann_estado_efectivo
    if reprocann_estado.to_s == 'activo' &&
       reprocann_vencimiento.present? && reprocann_vencimiento < Date.today
      'vencido'
    else
      reprocann_estado
    end
  end

  def saldo_cc
    cuenta_corriente&.saldo_disponible&.to_f
  end

  def limite_cc
    cuenta_corriente&.limite_credito&.to_f
  end

  def saldo_cc_g
    cuenta_corriente&.saldo_disponible_g&.to_f
  end

  def limite_cc_g
    cuenta_corriente&.limite_credito_g&.to_f
  end

  def cc_gramos_activo
    cuenta_corriente&.credito_gramos_activo? || false
  end

  def dispensado_mes_actual_g
    dispensaciones.no_canceladas.del_mes.sum(:cantidad).to_f
  end

  def porcentaje_limite_mensual
    return nil unless limite_dispensacion_mensual_g.present? && limite_dispensacion_mensual_g > 0
    [(dispensado_mes_actual_g / limite_dispensacion_mensual_g.to_f * 100).round(1), 100].min
  end

  private

  def dispatch_webhook
    WebhookDispatcher.dispatch(club, 'paciente.creado', {
      id:       id,
      nombre:   nombre_completo,
      dni:      dni,
      email:    email,
      telefono: telefono,
    })
  end

  def normalize_dni!
    return if dni.blank?
    self.dni_normalizado = dni.gsub(/\D/, "")
  end

  def assign_carnet_token
    self.carnet_token ||= SecureRandom.uuid
  end

  def fecha_nacimiento_pasada
    if fecha_nacimiento.present? && fecha_nacimiento >= Date.today
      errors.add(:fecha_nacimiento, "debe ser una fecha pasada")
    end
  end
end
