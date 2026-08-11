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

  # Multiplicadores del caché de prompt, sobre el precio de entrada del modelo: escribir cuesta
  # 1,25× y leer 0,1×. Ese 0,1 es de dónde sale el ahorro — el bloque fijo del prompt del
  # asistente son ~1.400 tokens que hoy se pagan enteros en cada dictado.
  CACHE_ESCRITURA = 1.25
  CACHE_LECTURA   = 0.10

  def self.costo_de(modelo:, input_tokens:, output_tokens:, cache_creation_tokens: 0, cache_read_tokens: 0)
    p = PRECIOS[modelo] || PRECIO_POR_DEFECTO
    entrada = (input_tokens.to_i * p[:entrada]) +
              (cache_creation_tokens.to_i * p[:entrada] * CACHE_ESCRITURA) +
              (cache_read_tokens.to_i     * p[:entrada] * CACHE_LECTURA)
    (entrada + (output_tokens.to_i * p[:salida])) / 1_000_000.0
  end

  def tokens
    input_tokens.to_i + output_tokens.to_i + cache_creation_tokens.to_i + cache_read_tokens.to_i
  end

  # Cuánto de la entrada vino de caché. Es la métrica para saber si el caché está funcionando:
  # si queda en 0 request tras request, algo está invalidando el prefijo.
  def cache_hit_ratio
    entrada = input_tokens.to_i + cache_creation_tokens.to_i + cache_read_tokens.to_i
    return 0.0 if entrada.zero?
    (cache_read_tokens.to_i * 100.0 / entrada).round(1)
  end
end
