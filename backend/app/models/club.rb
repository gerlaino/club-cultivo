class Club < ApplicationRecord
  include RestorableInterface
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

  before_validation :generar_slug, on: :create
  after_create :crear_geneticas_default!

  ROLES_DEFAULT    = %w[admin].freeze
  ROLES_VALIDOS_CLUB = %w[admin medico cultivador supervisor abogado auditor dispensador manicura delivery].freeze
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

  AVAILABLE_FEATURES = %w[
    ia_analisis
    ia_voz
    web_publica
    mailer
    iot
    alertas
    ariccame
    cuenta_corriente
    analytics
    multi_sede
    insumos
    bar
  ].freeze

  def feature?(key)
    features[key.to_s] == true
  end

  IA_TIERS = {
    'basico'     => { label: 'Básico',     limite_hora: 20,  color: '#64748b' },
    'pro'        => { label: 'Pro',        limite_hora: 60,  color: '#0891b2' },
    'enterprise' => { label: 'Enterprise', limite_hora: 200, color: '#7c3aed' },
  }.freeze

  def ia_config
    IA_TIERS[ia_tier] || IA_TIERS['basico']
  end

  def ia_limite_efectivo
    ia_limite_hora.positive? ? ia_limite_hora : ia_config[:limite_hora]
  end

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

  def twilio_auth_token
    return nil unless twilio_auth_token_enc.present?
    Rails.application.message_verifier(:twilio).verify(twilio_auth_token_enc)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def twilio_auth_token=(raw_token)
    self.twilio_auth_token_enc = raw_token.present? ? Rails.application.message_verifier(:twilio).generate(raw_token) : nil
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restaurar!
    update!(deleted_at: nil)
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