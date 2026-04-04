class Club < ApplicationRecord
  has_many :users,                dependent: :restrict_with_error
  has_many :salas,                dependent: :destroy
  has_many :lotes,                dependent: :destroy
  has_many :socios,               dependent: :destroy
  has_many :geneticas,            dependent: :destroy
  has_many :noticias,             dependent: :destroy
  has_many :eventos,              dependent: :destroy
  has_many :sedes,                dependent: :destroy
  has_many :movimientos_contables, class_name: 'MovimientoContable', dependent: :destroy
  has_many :costo_lotes,          class_name: 'CostoLote', dependent: :destroy
  has_many :tareas,               dependent: :destroy
  has_many :documentos,           dependent: :destroy
  has_many :document_templates,   dependent: :destroy
  has_many :patient_documents,    through: :socios
  has_many :plants,               through: :lotes

  has_one_attached :logo

  validates :name,  presence: true
  validates :slug,  presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  before_validation :generar_slug, on: :create

  ROLES_DEFAULT    = %w[admin medico agricultor cultivador abogado].freeze
  PASSWORD_DEFAULT = '123456Aa'.freeze

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

  def crear_usuarios_default!
    ROLES_DEFAULT.map do |rol|
      email = "#{rol}@#{slug}.clubcultivo.app"
      next if User.exists?(email: email)
      User.create!(
        club:       self,
        role:       rol,
        email:      email,
        password:   PASSWORD_DEFAULT,
        first_name: rol.capitalize,
        last_name:  name,
        )
    end.compact
  end

  def crear_geneticas_default!
    GENETICAS_INASE.map do |data|
      next if geneticas.exists?(nombre: data[:nombre])
      geneticas.create!(data)
    end.compact
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