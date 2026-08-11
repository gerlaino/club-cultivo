# Una llamada a la API de IA y lo que costó. Sólo se inserta.
#
# Existe para poder contestar dos preguntas que antes no tenían respuesta: cuánto consume cada
# organización (para cobrarlo) y cuánto nos cuesta (para no venderlo por debajo del costo).
class IaLlamada < ApplicationRecord
  self.table_name = 'ia_llamadas' # el inflector EN no pluraliza "llamada"

  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :user, optional: true

  # Los cinco lugares que llaman a la API. Sirven para ver QUÉ se usa, no sólo cuánto: si el
  # 90% es registro por voz, ahí es donde conviene optimizar.
  FUNCIONES = %w[
    asistente_parsear
    asistente_consultar
    analisis_lote
    plan_trabajo
    csv_import
  ].freeze

  # USD por millón de tokens, por modelo. Se usa sólo para calcular el costo AL INSERTAR — una
  # vez guardado, `costo_usd` no se recalcula: si mañana cambia el precio, los registros viejos
  # tienen que seguir diciendo lo que costaron entonces.
  PRECIOS = {
    'claude-sonnet-4-6'          => { entrada: 3.0, salida: 15.0 },
    'claude-haiku-4-5-20251001'  => { entrada: 1.0, salida:  5.0 },
    'claude-haiku-4-5'           => { entrada: 1.0, salida:  5.0 },
  }.freeze

  # Modelo desconocido (uno nuevo que todavía no está en la tabla): se cobra al precio más caro
  # que conocemos en vez de a cero. Un costo estimado de más se nota y se corrige; uno de menos
  # pasa desapercibido y se factura mal.
  PRECIO_POR_DEFECTO = { entrada: 3.0, salida: 15.0 }.freeze

  validates :funcion, inclusion: { in: FUNCIONES }
  validates :modelo,  presence: true

  scope :recientes,  -> { order(created_at: :desc) }
  scope :del_mes,    ->(fecha = Time.zone.today) { where(created_at: fecha.all_month) }
  scope :exitosas,   -> { where(ok: true) }

  def self.costo_de(modelo:, input_tokens:, output_tokens:)
    p = PRECIOS[modelo] || PRECIO_POR_DEFECTO
    ((input_tokens.to_i * p[:entrada]) + (output_tokens.to_i * p[:salida])) / 1_000_000.0
  end

  def tokens = input_tokens.to_i + output_tokens.to_i
end
