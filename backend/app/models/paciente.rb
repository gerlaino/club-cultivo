class Paciente < ApplicationRecord
  include RestorableInterface
  include Auditable
  # ALLOWLIST estricto: solo campos NO cifrados y no clínicos. Auditar dni/email/telefono/
  # reprocann_numero o cualquier campo clínico escribiría el valor DESCIFRADO en el rastro y
  # rompería el cifrado at-rest (ENC-01) + la privacidad de la historia clínica (fix AZ).
  # Lo valioso y seguro: identidad básica + vencimiento/estado REPROCANN (los críticos de la organización).
  auditar_solo :nombre, :apellido, :fecha_nacimiento, :reprocann_vencimiento, :reprocann_estado
  acts_as_paranoid
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User", optional: true
  belongs_to :deleted_by, class_name: "User", optional: true
  belongs_to :aprobado_por, class_name: "User", optional: true

  # La cuenta con la que entra a su portal. Opcional: los pacientes que ya existían no tienen, y
  # una organización sin el módulo no necesita crearlas. Ver `Pacientes::Acceso`.
  belongs_to :user, optional: true

  has_many :notas, class_name: "PacienteNota", dependent: :destroy
  has_many :direcciones_guardadas, class_name: 'DireccionPaciente', dependent: :destroy
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
  # TODO PACIENTE NACE CON CUENTA CORRIENTE (decisión de Germán, 18-sep-2026). Es la cuenta donde
  # cae el vuelto que no se pudo dar y lo que pagó de más, y se descuenta sola en la próxima. Nace
  # con límite 0: tener SALDO (a favor) es de todos; poder DEBER (`limite_credito`) lo decide el
  # admin por paciente, como siempre. Son dos cosas y estaban en un solo flag.
  after_create      :crear_cuenta_corriente!
  after_create_commit :dispatch_webhook

  validates :nombre, :apellido, :dni, :dni_normalizado, :fecha_nacimiento, presence: true
  # Unicidad DENTRO de la organización, no en toda la plataforma.
  #
  # Era global, leyendo el requisito del REPROCANN (una persona se registra con UN cultivador a
  # la vez) como si fuera una restricción de nuestra base. No lo es: quien se va de una
  # organización y entra a otra quedaba sin poder darse de alta hasta que la primera lo borrara
  # —algo que nadie tiene forma de pedir—, y el error de alta filtraba que ese DNI existe en
  # OTRA organización, que es un dato de salud de alguien que no es su paciente.
  #
  # El scope explícito no es redundante con acts_as_tenant: en consola, rakes y jobs la query
  # corre sin tenant fijado y sin esto compararía contra toda la plataforma.
  validates :dni_normalizado,
    uniqueness: { scope: :club_id, message: "ya está registrado en esta organización." },
    format:     { with: /\A\d{7,9}\z/, message: "debe tener 7 a 9 dígitos" }
  validate :fecha_nacimiento_pasada

  scope :for_club,          ->(club_id) { where(club_id: club_id) }
  scope :con_seguimiento,   -> { where(con_seguimiento_medico: true) }
  scope :sin_seguimiento,   -> { where(con_seguimiento_medico: false) }

  # ── Admisión ────────────────────────────────────────────────────────────────
  # Un paciente cargado desde el mostrador existe pero todavía no fue admitido. Puede editarse
  # y completarse; lo que NO puede es recibir producto hasta que admin o médico lo aprueben.
  scope :aprobados,             -> { where.not(aprobado_at: nil) }
  scope :pendientes_aprobacion, -> { where(aprobado_at: nil) }

  # Quiénes pueden CREAR (queda pendiente si no puede aprobar) y quiénes APROBAR.
  # El supervisor puede crear igual que el dispensador: los dos atienden el mostrador, y que uno
  # pudiera y el otro no era una incoherencia, no una regla.
  ROLES_CREAN   = %w[admin medico supervisor dispensador].freeze
  ROLES_APRUEBAN = %w[admin medico].freeze

  # Un alta nace APROBADA salvo que venga del mostrador. La excepción es el mostrador, no la
  # regla: las importaciones de padrón, los seeds, la migración de una organización y el alta de
  # admin/médico son admisiones válidas. Con el default al revés, importar 300 pacientes los
  # dejaría a todos sin poder retirar hasta aprobarlos de a uno.
  attr_accessor :desde_mostrador
  before_validation :aprobar_salvo_mostrador, on: :create

  def aprobado?  = aprobado_at.present?
  def pendiente_aprobacion? = aprobado_at.nil?

  def aprobar!(usuario)
    return false if aprobado?
    update!(aprobado_at: Time.current, aprobado_por: usuario, updated_by: usuario)
  end

  scope :reprocann_por_vencer, -> {
    where('reprocann_vencimiento IS NOT NULL')
      .where('reprocann_vencimiento <= ?', 30.days.from_now)
      .where('reprocann_vencimiento >= ?', Time.zone.today)
  }

  def nombre_completo
    "#{nombre} #{apellido}"
  end

  # A dónde se le puede mandar un paquete: el domicilio REPROCANN (de la ficha, del trámite) y
  # sus direcciones guardadas (`DireccionPaciente`, con nombre y una por defecto). `texto` se arma
  # acá para que el modal, la etiqueta y el PDF digan exactamente lo mismo.
  def domicilio
    return nil if domicilio_calle.blank?

    campos = { calle: domicilio_calle, altura: domicilio_altura, piso: domicilio_piso,
               depto: domicilio_depto, barrio: domicilio_barrio, ciudad: domicilio_ciudad }
    campos.merge(origen: 'domicilio', label: 'Domicilio REPROCANN', etiqueta: nil, texto: Paciente.direccion_texto(campos))
  end

  # Lo que ve el modal de dispensa. `envio` se mantiene por compatibilidad —es la por defecto—
  # para los clientes que todavía miran esa clave.
  def direcciones
    guardadas = direcciones_guardadas.ordenadas.map(&:como_json)
    { domicilio: domicilio, guardadas: guardadas, envio: guardadas.find { |d| d[:por_defecto] } }
  end

  # Una dirección por su nombre de origen: `domicilio`, o el id de una guardada.
  def direccion(origen)
    return domicilio if origen.to_s == 'domicilio'
    # Compatibilidad: `envio` era la única de envío; hoy es la por defecto.
    return direccion_por_defecto&.campos&.merge(etiqueta: direccion_por_defecto.etiqueta) if origen.to_s == 'envio'

    d = direcciones_guardadas.find_by(id: origen.to_s.to_i)
    d && d.campos.merge(etiqueta: d.etiqueta)
  end

  def direccion_por_defecto = direcciones_guardadas.ordenadas.first

  def self.direccion_texto(d)
    l1 = [d[:calle], d[:altura]].compact_blank.join(' ')
    pd = [d[:piso].presence && "Piso #{d[:piso]}", d[:depto].presence && "Depto #{d[:depto]}"].compact.join(' ')
    [l1, pd, d[:barrio], d[:ciudad]].compact_blank.join(', ')
  end

  # Dirección de entrega POR DEFECTO cuando nadie eligió: la guardada por defecto si hay, si no
  # el domicilio. Se mantiene para los llamadores viejos (`usar_domicilio_paciente`); lo nuevo
  # pide una por su nombre (`Envios::DireccionDeEntrega`).
  def direccion_entrega
    direccion('envio') || domicilio ||
      { calle: domicilio_calle, altura: domicilio_altura, piso: domicilio_piso, depto: domicilio_depto, barrio: domicilio_barrio, ciudad: domicilio_ciudad }
  end

  # Estado REPROCANN cruzado con la fecha: el campo manual puede quedar en
  # "activo" después de vencer — para mostrar, la fecha manda sobre el campo.
  # Estado a mostrar, cruzado con la fecha:
  # - 'activo' cuya fecha ya pasó → 'vencido' (rojo): cert aprobado que caducó.
  # - 'pendiente' NO se pisa aunque la fecha esté vencida: significa que hay un
  #   trámite de renovación en curso (se muestra ámbar, no rojo).
  # SUSPENDIDO POR POCO MOVIMIENTO (Germán, 23-sep-2026): está activo pero hace más de
  # DIAS_SIN_MOVIMIENTO días que no retira. No se marca a mano ni bloquea nada: es un aviso, y
  # deja de estarlo solo el día que vuelve a retirar. El que nunca retiró no está suspendido (es
  # un alta reciente, no un abandono). La regla vive acá: la lista, la ficha y el contador la usan.
  DIAS_SIN_MOVIMIENTO = 90

  def self.suspendido?(es_paciente:, ultima_dispensacion:, hoy: Time.zone.today)
    es_paciente && ultima_dispensacion.present? && ultima_dispensacion < hoy - DIAS_SIN_MOVIMIENTO
  end

  def reprocann_estado_efectivo
    if reprocann_estado.to_s == 'activo' &&
       reprocann_vencimiento.present? && reprocann_vencimiento < Time.zone.today
      'vencido'
    else
      reprocann_estado
    end
  end

  # Categorías del informe REPROCANN. Son MUTUAMENTE EXCLUYENTES y cubren todos los
  # casos: así los totales cierran por construcción en vez de contarse con cuatro
  # queries que se pisan entre sí (un paciente que vencía en 15 días caía a la vez en
  # "vigente" y en "vence en 30 días", y uno con número pero sin fecha no caía en ninguna).
  #
  # El orden importa: el ESTADO manda sobre la fecha, porque un trámite en curso todavía
  # no tiene certificado y por lo tanto tampoco tiene número ni vencimiento.
  REPROCANN_CATEGORIAS = %w[vigente por_vencer vencido pendiente sin_reprocann].freeze

  def self.reprocann_categoria(estado:, numero:, vencimiento:, hoy: Time.zone.today)
    return 'pendiente' if estado.to_s == 'pendiente'
    return 'sin_reprocann' if numero.blank?
    return 'vigente'    if vencimiento.blank? # certificado sin fecha cargada: existe igual
    return 'vencido'    if vencimiento < hoy
    return 'por_vencer' if vencimiento <= hoy + 30
    'vigente'
  end

  def reprocann_categoria
    self.class.reprocann_categoria(estado: reprocann_estado, numero: reprocann_numero,
                                   vencimiento: reprocann_vencimiento)
  end

  def saldo_cc
    cuenta_corriente&.saldo_disponible&.to_f
  end

  # Lo que tiene A FAVOR (saldo positivo). Cero si debe o no tiene cuenta.
  def saldo_a_favor
    [saldo_cc.to_f, 0.0].max
  end

  # La cuenta corriente, creándola si es un paciente anterior al alta automática.
  def cuenta_corriente!
    cuenta_corriente || crear_cuenta_corriente!
  end

  def crear_cuenta_corriente!
    create_cuenta_corriente!(club_id: club_id, saldo_disponible: 0, limite_credito: 0)
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

  def aprobar_salvo_mostrador
    self.aprobado_at ||= Time.current unless desde_mostrador
  end

  def normalize_dni!
    return if dni.blank?
    self.dni_normalizado = dni.gsub(/\D/, "")
  end

  def assign_carnet_token
    self.carnet_token ||= SecureRandom.uuid
  end

  def fecha_nacimiento_pasada
    if fecha_nacimiento.present? && fecha_nacimiento >= Time.zone.today
      errors.add(:fecha_nacimiento, "debe ser una fecha pasada")
    end
  end
end
