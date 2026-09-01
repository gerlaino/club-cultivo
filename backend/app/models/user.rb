class User < ApplicationRecord
  include Restorable
  include Permissions
  include Auditable
  # ALLOWLIST: solo lo relevante y NO cifrado. `role` es el evento de seguridad clave. Excluye
  # automáticamente el ruido de Devise (login/sign_in tracking, tokens, password) y los campos
  # cifrados at-rest (dni, phone) — que descifrados no deben quedar en el rastro.
  auditar_solo :role, :first_name, :last_name, :email, :email_personal
  belongs_to :club, optional: true

  # Cifrado at-rest del DNI y teléfono del operador (Ley 25.326 art. 9).
  # NO se cifra email: es el identificador de login de Devise (uniqueness + lookup
  # en cada autenticación) — cifrarlo es alto riesgo y queda fuera del alcance ENC-01.
  encrypts :dni
  encrypts :phone

  has_one_attached :avatar
  has_many :sala_cultivadores, class_name: 'SalaCultivador', foreign_key: 'user_id', dependent: :destroy
  has_many :salas_asignadas,   through: :sala_cultivadores, source: :sala
  has_many :user_sedes,        class_name: 'UserSede', foreign_key: 'user_id', dependent: :destroy
  has_many :sedes_asignadas,   through: :user_sedes, source: :sede
  has_many :push_subscriptions, dependent: :destroy
  has_many :disponibilidad_medicos, foreign_key: :medico_id, dependent: :destroy
  has_many :turnos_como_medico, class_name: 'Turno', foreign_key: :medico_id, dependent: :destroy

  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  enum :role, {
    super_admin:  'super_admin',
    admin:        'admin',
    medico:       'medico',
    cultivador:   'cultivador',
    supervisor:   'supervisor',
    abogado:      'abogado',
    auditor:      'auditor',
    dispensador:  'dispensador',
    manicura:     'manicura',
    paciente:     'paciente',
    delivery:     'delivery',
  }

  validates :role,  presence: true
  validates :email, presence: true, uniqueness: true

  # ── El paciente NO es parte del equipo ────────────────────────────────────
  #
  # Tiene un `User` porque necesita entrar a SU portal, no porque trabaje en la organización.
  # Contarlo como usuario del club rompía tres cosas a la vez: la pantalla de Equipo mostraba
  # el padrón entero, el cupo de usuarios del plan se llenaba con pacientes (que además ya
  # tienen su propio límite: se cobraban dos veces) y el panel del super admin informaba un
  # equipo de 63 personas donde había 3.
  #
  # Su cuenta se gestiona desde la ficha del paciente (`Pacientes::Acceso`), nunca desde los
  # endpoints de equipo.
  scope :del_equipo, -> { where.not(role: 'paciente') }

  # ── Roles que dependen de un módulo ───────────────────────────────────────
  #
  # Un cultivador en un club que apagó la suite Cultivo no tiene NADA que hacer: entraba
  # igual, caía en el home y cada endpoint suyo le devolvía 403 sin decirle por qué. Parecía
  # la app rota. Con esto el rechazo llega una sola vez, en el login, y explica el motivo.
  #
  # Con que UNA de las claves esté prendida alcanza (el supervisor trabaja en las dos suites).
  # Los roles que NO figuran acá nunca se bloquean: `admin` y `super_admin` administran,
  # `auditor` y `abogado` son lectura transversal y tienen que poder mirar el histórico de un
  # módulo dado de baja.
  MODULOS_POR_ROL = {
    'cultivador'  => %w[cultivo],
    'manicura'    => %w[cultivo],
    'supervisor'  => %w[cultivo produccion_dispensa],
    # El dispensador no vive sólo de la dispensa: también atiende el mostrador del Buffet
    # (caja de turno, ventas, stock del salón). Un club que compró sólo el Buffet tiene
    # dispensadores que trabajan todos los días, así que `bar` alcanza para dejarlo entrar.
    'dispensador' => %w[produccion_dispensa bar],
    # El repartidor depende del módulo DELIVERY, no de la suite entera. Apuntaba a
    # `produccion_dispensa` de cuando delivery no era un módulo aparte, y con eso dar de baja
    # Delivery no deshabilitaba a nadie: los repartidores seguían entrando a una sección que ya
    # no estaba contratada. (Delivery a su vez exige la suite, así que no se pierde nada.)
    'delivery'    => %w[delivery],
    # El paciente entra por su PORTAL y no tiene otro lado donde ir: sin ese módulo no hay nada
    # que mostrarle, así que tampoco puede loguearse. Misma lógica que el repartidor, que depende
    # del módulo Delivery y no de la suite entera.
    'paciente'    => %w[vista_paciente],
    'medico'      => %w[medico],
  }.freeze

  def modulos_requeridos = MODULOS_POR_ROL.fetch(role.to_s, [])

  # La ficha del paciente al que pertenece esta cuenta. Uno a uno: la crea `Pacientes::Acceso`.
  has_one :paciente, dependent: :nullify

  # ¿Sigue activo en la organización? Es lo que habilita su ingreso al portal, y lo maneja la
  # organización desde la ficha: el mismo interruptor que ya le impide dispensar y reservar.
  #
  # Sin ficha no bloquea. La cuenta la crea `Pacientes::Acceso` a partir de una ficha, así que
  # esto sólo pasa con cuentas sueltas de antes; bloquearlas dejaría afuera a gente que hoy entra
  # y nadie sabría por qué. La ficha BORRADA sí bloquea: eso es una baja.
  def paciente_activo?
    ficha = ActsAsTenant.without_tenant { Paciente.unscoped.find_by(user_id: id) }
    return true if ficha.nil?

    ficha.deleted_at.nil? && ficha.es_paciente?
  end

  # ¿Este usuario puede operar hoy? Sin club (super_admin) o sin módulo asociado al rol, sí.
  def rol_habilitado?
    requeridos = modulos_requeridos
    return true if requeridos.empty? || club.nil?

    # El paciente además necesita que la organización tenga el portal ABIERTO. Contratado y
    # abierto son dos cosas: el admin lo cierra desde Configuración → Portal del paciente para
    # terminar de cargarlo, o para bajarlo sin dar de baja el add-on. Cerrado, no entra —que es
    # justamente lo que ese interruptor prometía y no cumplía.
    return club.portal_paciente_disponible? if paciente?

    requeridos.any? { |clave| club.feature?(clave) }
  end

  # Está contratado pero la organización lo cerró. Se distingue del módulo apagado porque el
  # mensaje que corresponde es otro: no hay nada que contratar, hay que abrirlo.
  def portal_cerrado_por_la_organizacion?
    paciente? && club.present? && club.feature?(:vista_paciente) && !club.vista_paciente_activa?
  end

  # Cómo se llama, en castellano, el módulo que le falta al club para que este rol trabaje.
  def modulo_faltante_label
    modulos_requeridos
      .map { |c| (Club::SUITES[c] || Club::ADDONS[c] || {})[:label] || c.humanize }
      .join(' o ')
  end

  # Contraseña inicial de un usuario nuevo (y del "restablecer"). Se arma para poder DICTARSE
  # por teléfono sin equívocos: sin 0/O ni 1/l/I. El agrupado en bloques es sólo visual (lo arma
  # el frontend al mostrarla): el guion no es parte de la contraseña, para no dejar la duda de si
  # hay que tipearlo. Igual es temporal — Devise pide cambiarla con el link del mail.
  def self.password_temporal
    letras = ('a'..'z').to_a - %w[l o] + (('A'..'Z').to_a - %w[I O])
    numeros = ('2'..'9').to_a
    bloque = -> { 4.times.map { letras.sample }.join }
    "#{bloque.call}#{bloque.call}#{4.times.map { numeros.sample }.join}"
  end

  validate  :club_requerido_para_no_super_admin
  validate  :acceptable_avatar

  def nombre_completo
    "#{first_name} #{last_name}".strip
  end

  # Email REAL para mandarle notificaciones: el personal si lo cargó; si no, el de login
  # (que puede ser un identificador inventado tipo rol@club.com y rebotar).
  def email_notificacion
    email_personal.presence || email
  end

  KINDS_CULTIVADOR = %w[vegetativo floracion mixta madre clon].freeze
  KINDS_MANICURA   = %w[manicura].freeze

  # Sin sedes asignadas = acceso a todas las salas de su oficio, igual que el supervisor.
  # El fallback estaba repetido a mano en salas#index, salas#set_sala, lotes#index y lotes#set_lote,
  # y faltaba en plants#index y plants#kpis: el cultivador sin sedes veía todos los lotes y CERO
  # plantas. Vive acá para que no vuelva a divergir.
  def salas_ids_asignadas
    if cultivador?
      sedes = sedes_ids_asignadas
      scope = Sala.where(club_id: club_id).where(kind: KINDS_CULTIVADOR)
      scope = scope.where(sede_id: sedes) if sedes.any?
      scope.pluck(:id)
    elsif manicura?
      Sala.where(club_id: club_id).where(kind: KINDS_MANICURA).pluck(:id)
    else
      salas_asignadas.pluck(:id)
    end
  end

  def sedes_ids_asignadas
    sedes_asignadas.pluck(:id)
  end

  # Las sedes cuyo inventario este usuario puede ver. Sin sedes asignadas ve TODAS: es lo que
  # ya hacía `salas_ids_en_sedes_asignadas` para el cultivo, y es lo correcto para un club de
  # una sola sede o para un admin que no se asignó ninguna.
  #
  # Con sedes asignadas, en cambio, la asignación tiene que valer: un dispensador de la Finca
  # Norte veía —y podía dispensar— el stock de todas las sedes del club, que es justo lo que
  # la asignación existe para impedir.
  def sedes_visibles_ids
    asignadas = sedes_ids_asignadas
    asignadas.presence || club&.sedes&.pluck(:id) || []
  end

  # ¿Le alcanza con ver lo de sus sedes, o ve todo el club?
  def limitado_por_sede? = sedes_ids_asignadas.any?

  # ¿Esta persona ATIENDE el mostrador? Es quien pasa por la mesa: abre, recibe, dispensa de lo
  # que hay arriba y cierra contando.
  #
  # Vive acá, sobre el enum de roles que ya existe, y no como una lista adentro de `Dispensacion`:
  # una constante de roles metida en un modelo de dominio es un cuarto mecanismo de permisos, y en
  # este proyecto ya hay tres. El admin NO atiende — carga la mesa, la arquea y es el dueño de la
  # mercadería.
  ROLES_MOSTRADOR = %w[dispensador supervisor].freeze

  def atiende_mostrador? = ROLES_MOSTRADOR.include?(role.to_s)

  def salas_ids_en_sedes_asignadas
    sedes = sedes_ids_asignadas
    scope = Sala.where(club_id: club_id)
    # Sin sedes asignadas = acceso a todas las salas del club
    sedes.empty? ? scope.pluck(:id) : scope.where(sede_id: sedes).pluck(:id)
  end

  # ── Modo observador ───────────────────────────────────────────────────────
  #
  # El super admin entra a un club y lo ve entero, como lo ve su admin, sin poder tocar nada.
  # La mitad de "no tocar nada" ya estaba (`block_observer_writes!` rechaza todo verbo que no
  # sea GET); lo que faltaba era la mitad de "ver": el super admin no tiene club propio, así
  # que los ~370 puntos donde los controllers scopean por `current_user.club_id` le devolvían
  # nil y no veía absolutamente nada.
  #
  # En vez de tocar esos 370 puntos, el club efectivo se resuelve acá: mientras el modo está
  # activo, `club` y `club_id` responden el club observado. Es seguro porque sólo aplica a un
  # super_admin (nadie más puede tener `observer_club_id`) y porque la escritura ya está
  # bloqueada, así que ningún dato puede terminar guardado contra el club equivocado.
  #
  # OJO: es un override de lectura. La persistencia de la columna NO cambia — Active Record
  # escribe por `write_attribute`, y `club_id_original` deja a mano el valor real.
  # SUSPENDIDO (10-ago-2026). Poner en `true` lo reactiva entero.
  #
  # Está construido a medias y entrar a medias es peor que no entrar: el observador pasa el
  # gating por módulo pero después lo frenan los guards de ROL de cada controller (26
  # controllers con allowlists, 63 guards `require_*`), así que vería la app salpicada de
  # secciones vacías y 403. Si eso pasa mientras un club está trabajando, el club lo nota.
  #
  # Para terminarlo hace falta darle ROL EFECTIVO de admin del club observado —enmascarar
  # `User#role`, que es el enum de auth— y eso es una decisión aparte.
  #
  # Con la bandera apagada todo el modo queda inerte de una sola vez: sin club efectivo, sin
  # tenant, sin bloqueos de escritura, sin candado clínico y sin nada en /me. El sistema se
  # comporta exactamente como antes de construirlo.
  OBSERVADOR_HABILITADO = false

  def observando_club
    return nil unless modo_observador?
    Club.find_by(id: observer_club_id)
  end

  def modo_observador?
    return false unless OBSERVADOR_HABILITADO

    observer_club_id.present? && observer_expires_at&.future?
  end

  # El club real del usuario, sin la máscara del observador. Lo usa todo lo que necesita saber
  # quién es de verdad (auth, auditoría, el propio panel de plataforma).
  def club_id_original = read_attribute(:club_id)

  def club_original
    return nil if club_id_original.blank?
    Club.find_by(id: club_id_original)
  end

  def club_id
    return observer_club_id if modo_observador?
    super
  end

  def club
    return observando_club if modo_observador?
    super
  end

  private

  def club_requerido_para_no_super_admin
    return if super_admin?
    errors.add(:club, 'es obligatorio para este rol') if club_id.blank?
  end

  def acceptable_avatar
    return unless avatar.attached?
    errors.add(:avatar, 'es demasiado grande (máx 5MB)') if avatar.byte_size > 5.megabytes
    acceptable_types = %w[image/jpeg image/png image/webp]
    errors.add(:avatar, 'debe ser JPG/PNG/WebP') unless acceptable_types.include?(avatar.content_type)
  end
end