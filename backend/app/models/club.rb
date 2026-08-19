class Club < ApplicationRecord
  include RestorableInterface
  include Auditable
  # ALLOWLIST ESTRICTA: qué se le cambió al club y cuándo. Todo lo que se toca desde el panel de
  # plataforma —el plan, los módulos, la suspensión, la baja— deja rastro, porque hasta ahora
  # NADA lo dejaba: cuando un club reclamaba "yo no pedí que me cambien el plan" no había forma
  # de saber quién ni cuándo. Con dos personas operando el panel, eso es una discusión sin árbitro.
  #
  # Nunca se auditan credenciales: smtp_pass, twilio_auth_token_enc, pulse_api_key_enc quedan
  # fuera por no estar en esta lista, y una columna nueva tampoco se cuela sola.
  auditar_solo :name, :legal_name, :email, :slug, :plan, :plan_activo_hasta, :plan_trial,
               :features, :activo, :deleted_at, :demo, :ia_tier, :ia_limite_hora, :vista_paciente_activa

  # Se declaran para poder verificarlo en un test: que estén fuera no puede depender de que
  # alguien se acuerde de mirar la allowlist de arriba.
  CAMPOS_NUNCA_AUDITADOS = %w[
    smtp_pass twilio_auth_token_enc pulse_api_key_enc twilio_account_sid
  ].freeze

  # El concern audita contra `club_id`; para el club, su club es él mismo.
  def club_id = id

  belongs_to :deleted_by, class_name: "User", optional: true
  has_many :users
  has_many :salas,                dependent: :destroy
  has_many :lotes,                dependent: :destroy
  has_many :pacientes,            class_name: 'Paciente', dependent: :destroy
  has_many :reservas,             dependent: :destroy
  has_many :geneticas,            dependent: :destroy
  has_many :noticias,             dependent: :destroy
  has_many :eventos,              dependent: :destroy
  has_many :sedes,                dependent: :destroy
  has_many :movimientos_contables, class_name: 'MovimientoContable', dependent: :destroy
  has_many :compras_cuotas,        class_name: 'CompraCuotas',       dependent: :destroy
  has_many :unidades_negocio,      class_name: 'UnidadNegocio',      dependent: :destroy
  has_many :categorias_contables,  class_name: 'CategoriaContable',  dependent: :destroy
  has_many :gastos_recurrentes,    class_name: 'GastoRecurrente',    dependent: :destroy
  has_many :depositos,             dependent: :destroy
  has_many :categorias_producto,   class_name: 'CategoriaProducto', dependent: :destroy
  has_many :insumos,               dependent: :destroy
  has_many :insumo_compras,        class_name: 'InsumoCompra',       dependent: :destroy
  has_many :insumo_consumos,       class_name: 'InsumoConsumo',      dependent: :destroy
  has_many :bares,                 class_name: 'Barra',              dependent: :destroy
  has_many :bar_productos,         class_name: 'BarProducto',        dependent: :destroy
  has_many :bar_ventas,            class_name: 'BarVenta',           dependent: :destroy
  has_many :eventos_bar,           class_name: 'EventoBar',          dependent: :destroy
  has_many :costo_lotes,          class_name: 'CostoLote', dependent: :destroy
  has_many :tareas,               dependent: :destroy
  has_many :jornadas_laborales,   class_name: 'JornadaLaboral', dependent: :destroy
  has_many :documentos,           dependent: :destroy
  has_many :document_templates,   dependent: :destroy
  has_many :patient_documents,    through: :pacientes
  has_many :plants,               through: :lotes
  has_many :notas,           dependent: :destroy
  has_many :plantillas_mail, class_name: 'PlantillaMail', dependent: :destroy
  has_many :envios_masivos,  class_name: 'EnvioMasivo',  dependent: :destroy
  has_many :dispositivos,    dependent: :destroy
  has_many :reglas_ambientales, class_name: 'ReglaAmbiental', dependent: :destroy
  has_many :alertas,          dependent: :destroy
  has_many :alertas_internas, class_name: 'AlertaInterna', dependent: :destroy
  has_many :ariccame_registros, class_name: 'AriccameRegistro', dependent: :destroy
  has_many :plan_trabajos,      dependent: :destroy
  has_many :aplicacion_planes,  class_name: 'AplicacionPlan', dependent: :destroy
  has_many :pesajes_manicura,   class_name: 'PesajeManicura', dependent: :destroy
  has_many :stocks,             dependent: :destroy
  has_many :cobros,             dependent: :destroy
  has_many :rutas_entrega,      class_name: 'RutaEntrega', dependent: :destroy
  has_many :webhooks,           dependent: :destroy
  has_many :turnos,             dependent: :destroy
  has_many :check_ins,          dependent: :destroy

  has_one_attached :logo

  validates :name,  presence: true
  validates :slug,  presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :activos,    -> { where(deleted_at: nil) }
  scope :eliminados, -> { where.not(deleted_at: nil) }
  # OJO: `activos` sólo mira `deleted_at` — un club SUSPENDIDO (`activo: false`) pasa el filtro.
  # `operativos` es el que hay que usar cuando algo produce efectos hacia afuera (alertas, mails,
  # push): un club que dejó de pagar no debe seguir mandándole correo a sus pacientes.
  # `check_club_activo!` ya frena a los suspendidos en la API; los jobs no tenían equivalente.
  scope :operativos, -> { where(deleted_at: nil, activo: true) }
  # Clubes de verdad: los que operan. Excluye los demo (club modelo, copias de prueba), cuyos datos
  # son inventados y no deben entrar en métricas agregadas ni en benchmarking.
  scope :reales,     -> { where(demo: false) }
  scope :demo,       -> { where(demo: true) }

  before_validation :generar_slug, on: :create
  after_create :crear_geneticas_default!

  ROLES_DEFAULT    = %w[admin].freeze
  ROLES_VALIDOS_CLUB = %w[admin medico cultivador supervisor abogado auditor dispensador manicura delivery].freeze

  # Los que se ofrecen al dar de alta un club. Es un subconjunto de ROLES_VALIDOS_CLUB a
  # propósito: supervisor, abogado y auditor existen y funcionan, pero no son parte del arranque
  # de un club —se crean después, cuando el club sabe que los necesita—, y ofrecerlos en el alta
  # llenaba la pantalla de opciones que nadie tilda.
  ROLES_ALTA = %w[admin medico cultivador dispensador manicura].freeze

  # Los que un admin puede crear desde **Configuración → Equipo**, ya con el club andando. Suma
  # `delivery` a los del alta —un club que empieza a repartir necesita darlo de alta él mismo—,
  # y sigue dejando afuera supervisor, abogado y auditor: son casos puntuales que hoy no se
  # ofrecen. Un usuario que ya tenga uno de esos roles sigue funcionando normal; lo que no se
  # puede es crear uno nuevo desde la pantalla.
  ROLES_ALTA_CLUB = (ROLES_ALTA + %w[delivery]).freeze

  # Roles cuya oferta depende de un módulo contratado. `delivery` no lo necesita toda
  # organización: sin el módulo, ofrecerlo sería dar de alta a alguien que después no puede
  # entrar — `check_rol_habilitado!` lo rebota en el login y nadie entiende por qué.
  MODULO_POR_ROL_OPCIONAL = { 'delivery' => 'delivery' }.freeze

  # Los roles que ESTA organización puede dar de alta hoy, según lo que tenga contratado.
  def roles_para_alta(base = ROLES_ALTA_CLUB)
    base.reject { |rol| (m = MODULO_POR_ROL_OPCIONAL[rol]) && !feature?(m) }
  end

  ROLES_META = {
    'admin'       => { label: 'Admin',       desc: 'Acceso total al panel de la organización' },
    'medico'      => { label: 'Médico',      desc: 'Turnos, historia clínica e indicaciones' },
    'cultivador'  => { label: 'Cultivador',  desc: 'Salas, lotes y plantas' },
    'dispensador' => { label: 'Dispensador', desc: 'Entregas y dispensaciones' },
    'manicura'    => { label: 'Manicura',    desc: 'Post-cosecha y pesaje' },
    'supervisor'  => { label: 'Supervisor',  desc: 'Supervisión de cultivo y tareas' },
    'abogado'     => { label: 'Abogado',     desc: 'Documentación y compliance' },
    'auditor'     => { label: 'Auditor',     desc: 'Solo lectura para auditoría' },
    'delivery'    => { label: 'Delivery',    desc: 'Reparto de paquetes' },
  }.freeze

  PASSWORD_DEFAULT = ENV.fetch('CLUB_DEFAULT_PASSWORD', '123456Aa').freeze

  GENETICAS_INASE = [
    {
      nombre: 'ANANDA001', tipo: 'hibrida', thc: 17.37, cbd: 2.21,
      origen: 'Argentina', criador: 'Anandamida Organic S.A.S.',
      terpenos: 'Mirceno, Limoneno, Cariofileno',
      tiempo_floracion: 63, rendimiento: 400, altura: 150, dificultad: 'facil',
      descripcion: 'Primera variedad inscripta por una SAS argentina en el INASE. Alta germinación (98%), tallo púrpura, altura alta. Perfil balanceado THC/CBD ideal para uso medicinal.',
      registrada_inase: true, disponible: false, activa: true,
    },
    {
      nombre: 'CELOSA 10', tipo: 'hibrida', thc: 18.00, cbd: 1.20,
      origen: 'Argentina', criador: 'Diego Di Maggio',
      terpenos: 'Cariofileno, Humuleno, Mirceno',
      tiempo_floracion: 65, rendimiento: 450, altura: 130, dificultad: 'intermedia',
      descripcion: 'Variedad nacional inscripta en INASE de origen criollo con alta adaptación al clima argentino. Buena producción de resina y perfil aromático intenso.',
      registrada_inase: true, disponible: false, activa: true,
    },
    {
      nombre: 'POLARIS', tipo: 'hibrida', thc: 2.15, cbd: 12.00,
      origen: 'Argentina', criador: 'Lucía de Souza Madeira',
      terpenos: 'Limoneno, Mirceno, Pineno',
      tiempo_floracion: 60, rendimiento: 380, altura: 120, dificultad: 'facil',
      descripcion: 'Primera variedad feminizada inscripta en INASE. Dominante en CBD, excelente para uso medicinal. Cruce de Tangie con Girl Scout Cookies. Sabor cítrico con notas de tarta de naranja.',
      registrada_inase: true, disponible: false, activa: true,
    },
    {
      nombre: 'TROPICANA WFC', tipo: 'hibrida', thc: 8.83, cbd: 0.28,
      origen: 'Argentina', criador: 'Sweed Lab Seeds / Facundo Melingene',
      terpenos: 'Limoneno, Terpinoleno, Ocimeno',
      tiempo_floracion: 67, rendimiento: 500, altura: 140, dificultad: 'intermedia',
      descripcion: 'Primera semilla legal argentina de banco nacional. Alta producción de resina, aroma dulce cítrico. Mitad de las plantas producen flores violetas. Apta para interior y exterior.',
      registrada_inase: true, disponible: false, activa: true,
    },
    {
      nombre: 'EVA', tipo: 'sativa', thc: 9.50, cbd: 8.00,
      origen: 'Argentina', criador: 'León Verde S.A. / Martiniano Stanisio',
      terpenos: 'Pineno, Limoneno, Terpinoleno',
      tiempo_floracion: 70, rendimiento: 420, altura: 160, dificultad: 'intermedia',
      descripcion: 'Variedad nacional inscripta en INASE con perfil equilibrado THC/CBD. Fenotipo sativa con buena adaptación a climas cálidos. Ideal para uso diurno medicinal.',
      registrada_inase: true, disponible: false, activa: true,
    },
    {
      nombre: 'CHEM FELIX', tipo: 'hibrida', thc: 19.50, cbd: 0.80,
      origen: 'Argentina', criador: 'Felix Alberto Farías / Natalí Lazzaro',
      terpenos: 'Cariofileno, Limoneno, Mirceno',
      tiempo_floracion: 63, rendimiento: 460, altura: 120, dificultad: 'intermedia',
      descripcion: 'Genética nacional inscripta en INASE. Cruza local con perfil Chem predominante. Alta producción de THC con estructura robusta. Aroma terroso y diesel.',
      registrada_inase: true, disponible: false, activa: true,
    },
    {
      nombre: 'KALI FELIX', tipo: 'indica', thc: 20.00, cbd: 1.00,
      origen: 'Argentina', criador: 'Felix Alberto Farías / Natalí Lazzaro',
      terpenos: 'Mirceno, Cariofileno, Linalool',
      tiempo_floracion: 68, rendimiento: 430, altura: 100, dificultad: 'facil',
      descripcion: 'Variedad nacional inscripta en INASE. Perfil indica con efectos relajantes profundos. Baja proporción de hermafroditas. Floración tardía con buena producción de cogollos densos.',
      registrada_inase: true, disponible: false, activa: true,
    },
    {
      nombre: 'CANNPAT ONE', tipo: 'sativa', thc: 6.00, cbd: 14.00,
      origen: 'Argentina', criador: 'Cannabis Patagónico',
      terpenos: 'Pineno, Mirceno, Humuleno',
      tiempo_floracion: 72, rendimiento: 350, altura: 170, dificultad: 'intermedia',
      descripcion: 'Variedad patagónica inscripta en INASE. Genética desarrollada en el sur argentino con alta resistencia al frío. Perfil dominante en CBD, ideal para tratamientos medicinales.',
      registrada_inase: true, disponible: false, activa: true,
    },
  ].freeze

  def crear_usuarios_default!(roles: ROLES_DEFAULT, password: PASSWORD_DEFAULT)
    roles.select { |r| ROLES_VALIDOS_CLUB.include?(r) }.map do |rol|
      email = "#{rol}@#{slug}.com"
      next if User.exists?(email: email)
      User.create!(
        club:       self,
        role:       rol,
        email:      email,
        password:   password,
        first_name: rol.capitalize,
        last_name:  name,
      )
    end.compact
  end

  def crear_geneticas_default!
    GENETICAS_INASE.map do |data|
      next if Genetica.where(global: true, nombre: data[:nombre]).exists?
      Genetica.create!(data.merge(global: true, club_id: nil))
    end.compact
  end

  def eliminado? = deleted_at.present?

  # ── Qué se vende y qué se prende ──────────────────────────────────────────
  #
  # DOS SUITES, no trece casillas sueltas. Un club compra "cultivo" o "producción y dispensa"
  # (o las dos), y arriba se le suman los add-ons que le sirvan. Trece flags independientes
  # obligaban a tildar de a uno y a acordarse de todos: la primera vez que se olvida uno, el
  # club ve una sección a medias y pierde la confianza.
  #
  # Las suites NO se chequean con `feature?`: se chequean con `suite?`, y lo que un controller
  # exige es una suite o un add-on concreto (ver `require_feature!` en ApplicationController).
  SUITES = {
    'cultivo' => {
      label: 'Cultivo',
      desc:  'Genéticas, lotes, plantas, salas, cosecha, post-cosecha y tareas.',
    },
    'produccion_dispensa' => {
      label: 'Producción y dispensa',
      desc:  'Pacientes, stock, dispensaciones, reservas, cuenta corriente, delivery y contabilidad.',
    },
  }.freeze

  # Módulos que vienen DENTRO de una suite y no se prenden ni se apagan por separado: todo club
  # que compró la suite los tiene. El módulo médico y el correo al paciente viven de la ficha
  # del paciente, así que un club de sólo Cultivo —que no tiene pacientes— no los ve nunca.
  # Poder apagarlos era una perilla que no le servía a nadie y que, olvidada, dejaba al club
  # con media ficha.
  # `mailer` SALIÓ de acá y pasó a ADDONS. Cuando era "mandar un mail desde la ficha" no tenía
  # sentido venderlo aparte; ahora es un espacio propio —casilla, plantillas y envíos— y sí. El
  # movimiento va con backfill en la migración: derivado, lo tenía toda organización con la
  # suite, y sin backfill se quedaban todas sin correo el día del deploy.
  INCLUIDOS_EN_SUITE = {
    'medico' => 'produccion_dispensa',
  }.freeze

  INCLUIDOS_META = {
    'medico' => { label: 'Módulo médico', desc: 'Turnos, historia clínica e indicaciones.', requiere: nil },
  }.freeze

  # Add-ons: se suman a una suite y SÍ se venden por separado.
  #
  #   `pack`     — a QUÉ suite le sirve. Sin esto la pantalla del super admin era una lista plana
  #                de diez cosas y no se entendía para qué era cada una: el Buffet extiende la
  #                dispensa, el IoT extiende el cultivo. `nil` = transversal, sirve a las dos.
  #   `requiere` — de qué depende para funcionar DE VERDAD. Prenderlo no alcanza.
  ADDONS = {
    'bar'      => { label: 'Buffet',         pack: 'produccion_dispensa', desc: 'Punto de venta, caja de turno y stock del salón.',   requiere: 'EN CONSTRUCCIÓN: se puede prender para probarlo, todavía no para vender.' },
    'eventos'  => { label: 'Eventos',        pack: 'produccion_dispensa', desc: 'Fiestas y catas: provisión desde depósitos, entradas y rendición.', requiere: 'El Buffet tiene que estar activo.' },
    'delivery' => { label: 'Delivery',       pack: 'produccion_dispensa', desc: 'Reparto a domicilio: paquetes, rutas, firma de entrega y cobro contra-entrega.', requiere: 'La suite de Producción y dispensa tiene que estar activa.' },
    'mailer'   => { label: 'Correo electrónico', pack: 'produccion_dispensa', desc: 'Casilla propia, plantillas de mail y envíos a los pacientes.', requiere: 'Casilla de la organización conectada en Configuración → Correo electrónico.' },
    'vista_paciente' => { label: 'Portal del paciente', pack: 'produccion_dispensa', desc: 'Lo que ve el paciente cuando entra: el catálogo, las novedades y los eventos que publica la organización. Cada paciente que se da de alta recibe su cuenta.', requiere: 'INCOMPLETO: falta su tablero (carnet y dispensaciones).' },
    'whatsapp' => { label: 'WhatsApp',       pack: 'produccion_dispensa', desc: 'Avisos de entrega por WhatsApp.',                    requiere: 'Cuenta de Twilio de la organización (SID, token y número).' },
    'ariccame' => { label: 'ARICCAME',       pack: 'produccion_dispensa', desc: 'Reporte regulatorio de dispensaciones y stock.',     requiere: 'La integración está simulada: no transmite nada.' },

    'iot'      => { label: 'Ambiente / IoT', pack: 'cultivo', desc: 'Sensores, lecturas automáticas y reglas.',           requiere: 'Hardware de la organización (Sonoff u otro) o importación por CSV.' },

    # Transversales: sirven a las dos suites, y con las dos contratadas rinden más que con una.
    'ia'       => { label: 'Asistente IA',   pack: nil, desc: 'Registro por voz de salas, lotes y plantas, plan de trabajo y lectura de CSV.', requiere: 'ANTHROPIC_API_KEY en el entorno.' },
    # Va aparte de `ia` a propósito: el dictado por voz y el chatbot se venden distinto y se
    # prueban distinto. Una organización puede querer que su equipo registre hablando sin abrirle
    # a nadie una ventana que consulta la base entera.
    'chatbot'  => { label: 'Chatbot del admin', pack: nil, desc: 'El admin pregunta sobre su organización y el sistema contesta con sus propios datos. Contesta sobre lo que la organización tenga contratado: con Cultivo, rendimiento y producción; con Producción y dispensa, costos y pérdidas.', requiere: 'El Asistente IA tiene que estar activo. EN PRUEBA: contesta pocas preguntas todavía.' },
  }.freeze

  # A qué suite le sirve cada add-on. `nil` = a las dos.
  def self.pack_de_addon(clave) = ADDONS.dig(clave.to_s, :pack)

  # Add-ons que NO se pueden prender, ni siquiera para probar: no funcionan y prenderlos sólo
  # genera una expectativa que después hay que explicar. La pantalla los muestra apagados y con
  # el motivo, y la API los rechaza — el candado no puede vivir sólo en el toggle.
  #
  # Están acá y no en EN_CONSTRUCCION porque su código SÍ existe y se prueba: sacarlos del
  # catálogo dejaría sus specs sin forma de armar un club que los tenga.
  ADDONS_BLOQUEADOS = {
    'whatsapp' => 'Falta dar de alta la cuenta de Twilio de la plataforma.',
    'ariccame' => 'La transmisión está simulada: no le llega nada al organismo.',
  }.freeze

  def self.addon_bloqueado?(clave) = ADDONS_BLOQUEADOS.key?(clave.to_s)

  # Módulos que TODAVÍA NO EXISTEN. Se listan para que el super admin sepa que vienen, pero no
  # se pueden activar: prenderlos no haría nada y prometerle al club algo que no está es peor
  # que no ofrecerlo. Distinto de ADDONS_INCOMPLETOS, que funcionan a medias y sólo avisan.
  # Vacío hoy, y el cajón se queda: es el lugar donde poner un módulo que ya tiene código pero
  # todavía no se puede vender. `feature?` devuelve false para lo que esté acá, tenga lo que
  # tenga guardado, así que sirve para escribir un módulo entero sin que se filtre a nadie.
  EN_CONSTRUCCION = {}.freeze

  # Add-ons que funcionan a medias: vienen apagados por defecto y el super admin muestra la
  # advertencia de `requiere` antes de dejar activarlos. No se bloquean por completo —eso
  # dejaría su código inalcanzable— pero nadie los prende sin enterarse de qué les falta.
  ADDONS_INCOMPLETOS = %w[bar eventos chatbot vista_paciente].freeze

  # Se mantiene para compatibilidad: hay clubes con las claves viejas guardadas en `features`.
  AVAILABLE_FEATURES = (SUITES.keys + ADDONS.keys + INCLUIDOS_EN_SUITE.keys).freeze

  # Lo único que el super admin puede prender y apagar a mano. Los incluidos salen de su suite
  # y los de EN_CONSTRUCCION no existen todavía: aceptarlos por parámetro sería guardar un
  # `true` que nadie lee.
  FEATURES_EDITABLES = (SUITES.keys + ADDONS.keys).freeze

  # Equivalencias con el esquema viejo, para que un club existente no pierda accesos.
  # `alertas`, `analytics`, `multi_sede`, `insumos` y `cuenta_corriente` dejan de ser flags:
  # son parte del núcleo de sus suites y no tenía sentido poder apagarlas por separado.
  FEATURES_LEGACY = {
    'ia_analisis'      => 'ia',
    'ia_voz'           => 'ia',
    'cuenta_corriente' => 'produccion_dispensa',
    'analytics'        => 'cultivo',
    'multi_sede'       => 'cultivo',
    'insumos'          => 'cultivo',
    'alertas'          => 'cultivo',
    # `web_publica` NO se mapea a `vista_paciente` a propósito. Era la clave de algo que nunca se
    # vendió ni funcionó, y ahora el Portal del paciente es un add-on que se cobra: dejar la
    # equivalencia sería una puerta de atrás por la que una organización se lo lleva gratis
    # porque alguien probó una bandera en 2026. Se pide por su clave nueva y por ninguna otra.
  }.freeze

  # Con qué nace un club nuevo: las dos suites y el Buffet, que funciona sin nada de afuera.
  # Médico y correo no se listan porque ya vienen con Producción y dispensa. Los que dependen
  # de algo externo (IoT, IA, WhatsApp) y los incompletos se prenden cuando el club los tenga
  # resueltos.
  FEATURES_POR_DEFECTO = {
    'cultivo'             => true,
    'produccion_dispensa' => true,
    'bar'                 => true,
    # Delivery viene prendido por el mismo criterio que el Buffet: funciona sin nada de afuera y
    # el alta deja destildarlo. Una organización que no reparte simplemente no da de alta
    # repartidores; una que sí, no tiene que pedir que se lo habiliten.
    'delivery'            => true,
    # Correo nace prendido por el mismo motivo: hasta ayer lo tenía toda organización con la
    # suite (era derivado), y hacer que ahora haya que acordarse de tildarlo es justo el olvido
    # que deja al cliente con media ficha. Que sea contratable significa que se puede DAR DE
    # BAJA, no que haya que pedirlo.
    'mailer'              => true,
  }.freeze

  # Features tal como las ve el frontend: las guardadas MÁS las claves viejas derivadas.
  # `multi_sede`, `analytics`, `insumos`, `alertas` y `cuenta_corriente` dejaron de existir
  # como bandera propia (son núcleo de sus suites), pero hay vistas que las consultan por
  # nombre para decidir qué sección mostrar.
  def features_expandidas
    base = features.dup
    # Los incluidos no se guardan: se derivan de su suite, y son verdad para todo club que la
    # tenga. Guardarlos habría dejado dos fuentes que se contradicen en cuanto alguien apague
    # la suite y se olvide del módulo.
    INCLUIDOS_EN_SUITE.each { |modulo, suite| base[modulo] = true if base[suite] == true }
    FEATURES_LEGACY.each do |viejo, nuevo|
      base[viejo] = true if base[nuevo] == true
      # Y al revés: una organización con la clave VIEJA guardada tiene la capacidad nueva. Sin
      # esto, `feature?('ia')` decía true (lo deriva de `ia_voz`) mientras esta lista decía
      # false, así que el backend dejaba pasar y la pantalla escondía el botón — el módulo
      # quedaba contratado e invisible, que es la peor de las dos respuestas.
      base[nuevo] = true if base[viejo] == true && !EN_CONSTRUCCION.key?(nuevo)
    end
    base
  end

  def suite?(key)
    features[key.to_s] == true
  end

  # ¿Este módulo viene incluido en una suite que el club tiene?
  def incluido_por_suite?(key)
    suite = INCLUIDOS_EN_SUITE[key.to_s]
    suite.present? && features[suite] == true
  end

  def en_construccion?(key) = EN_CONSTRUCCION.key?(key.to_s)

  # Mapa inverso: qué banderas VIEJAS habilitan cada capacidad nueva. Se deriva de
  # FEATURES_LEGACY para no mantener dos listas que se contradigan.
  FEATURES_LEGACY_INVERSO = FEATURES_LEGACY.each_with_object({}) do |(viejo, nuevo), acc|
    (acc[nuevo] ||= []) << viejo
  end.freeze

  # ¿Está habilitada esta capacidad? Acepta el nombre nuevo o cualquiera de los viejos que
  # equivalían a él: un club con `ia_voz` guardado sigue teniendo el asistente.
  def feature?(key)
    k = key.to_s
    # Lo que todavía no existe no está habilitado para nadie, tenga lo que tenga guardado.
    return false if EN_CONSTRUCCION.key?(k)
    # Dado de baja y con el plazo ya cumplido: se apaga aunque la bandera siga guardada. El job
    # que las limpia corre una vez por día, así que entre el vencimiento y la corrida hay una
    # ventana — acá se cierra, para que nadie siga usando un módulo que ya terminó.
    return false if baja_cumplida?(k)
    return true  if features[k] == true
    return true  if incluido_por_suite?(k)

    FEATURES_LEGACY_INVERSO.fetch(k, []).any? { |viejo| features[viejo] == true }
  end

  # ¿El portal del paciente está DISPONIBLE hoy para esta organización?
  #
  # Son dos llaves distintas y las dos tienen que estar puestas:
  #
  #   `feature?(:vista_paciente)` — lo CONTRATADO. Lo prende y lo apaga el super admin.
  #   `vista_paciente_activa`     — el interruptor de la ORGANIZACIÓN, en Configuración → Portal.
  #                                 Es su forma de cerrarlo mientras lo termina de cargar, o de
  #                                 bajarlo sin dar de baja el add-on.
  #
  # Vive acá y en un solo lugar a propósito: lo preguntan el login (`User#rol_habilitado?`) y el
  # área de pacientes (`Portal::BaseController`). Hasta hoy el interruptor no lo leía NADIE —se
  # guardaba, se mostraba en pantalla y no hacía nada—, que es la peor versión de "la regla vive
  # en dos lugares": vivía en cero.
  def portal_paciente_disponible?
    feature?(:vista_paciente) && vista_paciente_activa?
  end

  def addon_disponible?(key)
    feature?(key)
  end

  # ── Baja de un módulo: se programa, no se corta ─────────────────────────────
  #
  # La organización paga por período. Apagarle un módulo el día que se decide la baja es cobrarle
  # el mes y no prestárselo, así que la baja fija una FECHA y hasta ahí sigue andando igual.
  #
  # El período es MENSUAL: la baja cae a fin del mes en curso. `plan_activo_hasta` NO es el fin
  # del período — es cuándo se le vence la suscripción entera, y suele estar cargada a un año o
  # más. Tomándola como fin de período, dar de baja un módulo en agosto de 2026 decía "sigue
  # andando hasta el 26 de febrero de 2028": año y medio de un módulo que el cliente ya canceló.
  #
  # Sí funciona como TECHO: si la suscripción vence antes que el fin de mes, el módulo no puede
  # sobrevivirla.
  def baja_programada_para(key)
    f = features_baja[key.to_s]
    f && Date.parse(f.to_s)
  rescue ArgumentError
    nil
  end

  def baja_programada?(key) = baja_programada_para(key).present?

  def baja_cumplida?(key)
    fecha = baja_programada_para(key)
    fecha.present? && fecha < Time.zone.today
  end

  def fin_de_periodo
    fin_de_mes = Time.zone.today.end_of_month
    return fin_de_mes if plan_activo_hasta.blank?

    [fin_de_mes, plan_activo_hasta].min
  end

  def programar_baja_modulo!(key, hasta: nil)
    k = key.to_s
    return false unless features[k] == true

    update!(features_baja: features_baja.merge(k => (hasta || fin_de_periodo).to_s))
  end

  # Se arrepintió antes de que venza: vuelve a quedar como si nada.
  def cancelar_baja_modulo!(key)
    update!(features_baja: features_baja.except(key.to_s))
  end

  # Módulos cuya baja ya venció y hay que apagar de verdad.
  def bajas_vencidas
    features_baja.keys.select { |k| baja_cumplida?(k) }
  end

  # ── ¿Este módulo ANDA de verdad? ──────────────────────────────────────────
  #
  # Prender el interruptor no alcanza: el WhatsApp necesita Twilio, el Correo necesita SMTP,
  # el IoT necesita hardware. Antes eso sólo estaba escrito en el campo `requiere` como nota al
  # pie, así que se prendían los nueve, se mostraba la demo y no funcionaba ninguno — sin que
  # la pantalla dijera por qué.
  #
  # Devuelve qué le falta al módulo para funcionar, o nil si ya está listo. Sólo tiene sentido
  # preguntarlo de un módulo prendido.
  def falta_para_funcionar(key)
    case key.to_s
    when 'whatsapp' then twilio_configurado?  ? nil : 'Falta cargar la cuenta de Twilio (SID, token y número).'
    when 'mailer'   then smtp_configured?     ? nil : 'Falta cargar el SMTP de la organización.'
    when 'iot'      then iot_listo?           ? nil : 'Todavía no hay ningún dispositivo dando señales.'
    when 'ia'       then ENV['ANTHROPIC_API_KEY'].present? ? nil : 'Falta ANTHROPIC_API_KEY en el entorno de la plataforma.'
    when 'eventos'  then feature?('bar')      ? nil : 'Necesita el Buffet activo.'
    when 'chatbot'  then feature?('ia')        ? nil : 'Necesita el Asistente IA activo.'
    end
  end

  # Qué va a poder contestar el chatbot en ESTA organización, según los datos que tenga cargados.
  #
  # No bloquea el toggle a propósito. Un bloqueo duro tiene dos problemas: no se podría prender
  # para probarlo ni en una demo, y una organización sin datos hoy los tiene el mes que viene —
  # el toggle quedaría muerto hasta que alguien note que ya se puede, y nadie va a estar mirando.
  # Es la misma política que `ADDONS_INCOMPLETOS`: avisar qué falta, no cerrar la puerta.
  #
  # Los umbrales son los de las consultas (`Ia::Consultas::*::MINIMO_*`) y se leen de ahí para no
  # tener los mismos números escritos en dos lados.
  def chatbot_capacidades
    cosechados = lotes.where.not(rendimiento_real_g: nil)
    por_gen    = cosechados.where.not(genetica_id: nil).group(:genetica_id).count
    con_minimo = por_gen.count { |_id, n| n >= Ia::Consultas::RendimientoPorGenetica::MINIMO_LOTES }

    [
      { pregunta: 'Qué se va a cosechar',
        puede:    lotes.where(estado: Ia::Consultas::ProduccionProxima::EN_CURSO).any?,
        falta:    'No hay lotes en floración ni en post-cosecha ahora mismo.' },
      { pregunta: 'Qué genética rinde mejor',
        # Hacen falta DOS que lleguen al mínimo: con una sola no hay con qué compararla.
        puede:    con_minimo >= Ia::Consultas::RendimientoPorGenetica::MINIMO_COMPARABLES,
        falta:    "#{con_minimo} genética(s) llegan a #{Ia::Consultas::RendimientoPorGenetica::MINIMO_LOTES} " \
                  "lotes cosechados y hacen falta #{Ia::Consultas::RendimientoPorGenetica::MINIMO_COMPARABLES} " \
                  "para poder compararlas (la que más tiene: #{por_gen.values.max || 0} lotes)." },
      { pregunta: 'Qué se muere y por qué',
        puede:    plants.count >= Ia::Consultas::PerdidasPorMotivo::MINIMO_PLANTAS,
        falta:    "Hacen falta #{Ia::Consultas::PerdidasPorMotivo::MINIMO_PLANTAS} plantas " \
                  "registradas para que un porcentaje signifique algo (hay #{plants.count})." },
      { pregunta: 'Cuánto cuesta el gramo',
        puede:    costo_lotes.where.not(costo_por_gramo: nil).count >= Ia::Consultas::CostoPorGenetica::MINIMO_LOTES,
        falta:    "Hay #{costo_lotes.where.not(costo_por_gramo: nil).count} lotes con el costo " \
                  "cargado; hacen falta #{Ia::Consultas::CostoPorGenetica::MINIMO_LOTES}." },
    ]
  end

  # El IoT está listo cuando hay por dónde entren datos: hardware propio dado de alta o la
  # cuenta de Pulse Grow cargada.
  def iot_listo? = pulse_configurado? || dispositivos.any?

  # Los tres estados que el super admin necesita distinguir de un vistazo:
  #   :andando       → prendido y funcionando
  #   :falta_config  → prendido, pero le falta algo y NO hace nada todavía
  #   :apagado       → no contratado
  #   :en_construccion → no existe todavía
  def estado_modulo(key)
    return :en_construccion if en_construccion?(key)
    return :apagado         unless feature?(key)
    falta_para_funcionar(key) ? :falta_config : :andando
  end

  # ¿Este add-on está terminado? El super admin lo usa para advertir antes de activarlo.
  def addon_incompleto?(key)
    ADDONS_INCOMPLETOS.include?(key.to_s)
  end

  # Dos topes con propósitos distintos:
  #
  # `limite_hora` es una protección contra ráfagas (un bucle, un botón trabado) y se cuenta en
  # LLAMADAS, que para eso alcanza. `limite_mes` es el tope que se VENDE y se cuenta en
  # **créditos** (`IaLlamada::USD_POR_CREDITO`), no en llamadas.
  #
  # Contaba llamadas y medía mal: una importación de plan de trabajo paga hasta 4.096 tokens de
  # salida y un mapeo de CSV 512 — ocho veces menos por el mismo cupo. Una organización que sólo
  # importa CSV consumía su tope sin costarnos casi nada y otra que vive del plan de trabajo nos
  # costaba ocho veces más por lo mismo. Los números no cambiaron al pasar a créditos porque
  # están elegidos para que un dictado ≈ 1 crédito: 500 créditos siguen siendo ~500 dictados.
  IA_TIERS = {
    'basico'     => { label: 'Básico',     limite_hora: 20,  limite_mes:    500, color: '#64748b' },
    'pro'        => { label: 'Pro',        limite_hora: 60,  limite_mes:  2_000, color: '#0891b2' },
    'enterprise' => { label: 'Enterprise', limite_hora: 200, limite_mes: 10_000, color: '#7c3aed' },
  }.freeze

  def ia_config
    IA_TIERS[ia_tier] || IA_TIERS['basico']
  end

  def ia_limite_efectivo
    ia_limite_hora.positive? ? ia_limite_hora : ia_config[:limite_hora]
  end

  def ia_limite_mes = ia_config[:limite_mes]

  def smtp_configured?
    smtp_host.present? && smtp_user.present? && smtp_pass.present?
  end

  def smtp_settings
    {
      address:              smtp_host,
      port:                 smtp_port || 587,
      user_name:            smtp_user,
      password:             smtp_pass,
      authentication:       :plain,
      enable_starttls_auto: true,
    }
  end

  # ── Envío de email: plataforma-gestionado por defecto, "propio" si el club conectó su casilla ──
  PLATFORM_FROM = ENV.fetch('MAIL_FROM', 'noreply@cultivoespacial.com').freeze

  # Servidor/puerto SMTP por dominio de email — para que el club solo cargue email + contraseña.
  SMTP_PROVIDERS = {
    'gmail.com'      => { host: 'smtp.gmail.com',      port: 587 },
    'googlemail.com' => { host: 'smtp.gmail.com',      port: 587 },
    'outlook.com'    => { host: 'smtp.office365.com',  port: 587 },
    'hotmail.com'    => { host: 'smtp.office365.com',  port: 587 },
    'live.com'       => { host: 'smtp.office365.com',  port: 587 },
    'live.com.ar'    => { host: 'smtp.office365.com',  port: 587 },
    'yahoo.com'      => { host: 'smtp.mail.yahoo.com', port: 587 },
    'yahoo.com.ar'   => { host: 'smtp.mail.yahoo.com', port: 587 },
  }.freeze

  def self.smtp_provider_for(email)
    dominio = email.to_s.split('@').last&.downcase
    SMTP_PROVIDERS[dominio]
  end

  # El club conectó su propia casilla (manda desde su email). Es requisito para enviar.
  def email_propio? = smtp_configured?

  # 'propio' (correo conectado) | 'sin_configurar'.
  def email_modo = email_propio? ? 'propio' : 'sin_configurar'

  # Remitente: la casilla del club.
  def email_from
    "#{smtp_from_name.presence || name} <#{smtp_from.presence || smtp_user}>"
  end

  def email_delivery_options
    smtp_settings
  end

  def twilio_configurado?
    twilio_account_sid.present? && twilio_auth_token_enc.present? && twilio_whatsapp_from.present?
  end

  # Estado del WhatsApp del club (derivado, no se persiste):
  #   conectado     → el super_admin ya provisionó Twilio.
  #   pendiente     → el admin solicitó activación (cargó su número), falta provisionar.
  #   sin_configurar → nada todavía.
  def whatsapp_estado
    return 'conectado'  if twilio_configurado?
    return 'pendiente'  if whatsapp_numero.present?
    'sin_configurar'
  end

  # ── Pulse Grow ────────────────────────────────────────────────────────────────
  # La API key la carga el SUPER ADMIN al activar el add-on de ambiente/IoT: es una
  # credencial de un servicio externo, no algo que el club deba pegar en una pantalla.
  def pulse_api_key
    return nil if pulse_api_key_enc.blank?
    Rails.application.message_verifier(:pulse).verify(pulse_api_key_enc)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def pulse_api_key=(raw)
    self.pulse_api_key_enc =
      raw.present? ? Rails.application.message_verifier(:pulse).generate(raw) : nil
  end

  def pulse_configurado? = pulse_api_key_enc.present?

  def twilio_auth_token
    return nil unless twilio_auth_token_enc.present?
    Rails.application.message_verifier(:twilio).verify(twilio_auth_token_enc)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def twilio_auth_token=(raw_token)
    self.twilio_auth_token_enc = raw_token.present? ? Rails.application.message_verifier(:twilio).generate(raw_token) : nil
  end

  # ── Dar de baja vs eliminar ────────────────────────────────────────────────────
  # Son dos cosas distintas y se confundían en una sola acción:
  #
  # SUSPENDER (`activo: false`) — el club dejó de pagar o está en pausa. Sigue en la lista,
  #   sus datos intactos, pero nadie puede entrar. Se reactiva y sigue como estaba.
  #
  # ELIMINAR (`deleted_at`) — el club se va. Sale de la lista, y su nombre, los emails de sus
  #   usuarios y los DNI de sus pacientes quedan LIBRES para volver a usarse. Es soft delete:
  #   se puede restaurar mientras nadie haya tomado esos identificadores.
  def suspender!
    update!(activo: false)
  end

  def reactivar!
    update!(activo: true)
  end

  def suspendido? = !activo?

  # Al eliminar hay que soltar los identificadores únicos, o el nombre y los emails quedan
  # ocupados por un club que ya no existe. El sufijo es reversible: guarda el valor original
  # a la vista para poder devolverlo al restaurar, sin agregar columnas.
  SUFIJO_ELIMINADO = '_eliminado_'

  def soft_delete!
    transaction do
      marca = "#{SUFIJO_ELIMINADO}#{id}"
      update!(deleted_at: Time.current, slug: "#{slug}#{marca}")
      users.where.not(role: 'super_admin').find_each do |u|
        u.update_columns(email: "#{u.email}#{marca}")
      end
      # Los pacientes son paranoid: al borrarlos, su DNI sale del índice de unicidad
      # (que es GLOBAL por requisito REPROCANN) y puede darse de alta en otro club.
      ActsAsTenant.with_tenant(self) { pacientes.find_each(&:destroy) }
    end
  end

  def restaurar!
    transaction do
      marca = "#{SUFIJO_ELIMINADO}#{id}"
      update!(deleted_at: nil, slug: slug.to_s.delete_suffix(marca))
      User.unscoped.where(club_id: id).find_each do |u|
        u.update_columns(email: u.email.delete_suffix(marca)) if u.email.end_with?(marca)
      end
      ActsAsTenant.with_tenant(self) { Paciente.only_deleted.where(club_id: id).find_each(&:restore) }
    end
  end

  private

  def generar_slug
    return if slug.present?
    base = name.to_s.downcase
               .gsub(/[áàäâ]/, 'a').gsub(/[éèëê]/, 'e')
               .gsub(/[íìïî]/, 'i').gsub(/[óòöô]/, 'o')
               .gsub(/[úùüû]/, 'u').gsub(/ñ/, 'n')
               .gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '_')
               .strip
    candidate = base
    counter   = 1
    while Club.where(slug: candidate).exists?
      candidate = "#{base}_#{counter}"
      counter  += 1
    end
    self.slug = candidate
  end
end