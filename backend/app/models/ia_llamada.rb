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
    chatbot
    analisis_lote
    plan_trabajo
    csv_import
  ].freeze

  # Cómo se llama cada función en pantalla. Sin esto el panel muestra la clave cruda
  # (`asistente_parsear`), que no le dice nada a quien lo lee.
  #
  # `chatbot` va aparte de `asistente_consultar` a propósito: los dos "consultan", pero uno mira
  # los datos de la organización y el otro es el agrónomo genérico. Mezclados en una sola fila no
  # se puede saber cuál se está usando ni cuál conviene apagar.
  ETIQUETAS = {
    'asistente_parsear'   => 'Registro por voz',
    'asistente_consultar' => 'Consulta al agrónomo',
    'chatbot'             => 'Chatbot del admin',
    'analisis_lote'       => 'Análisis de lote',
    'plan_trabajo'        => 'Importar plan de trabajo',
    'csv_import'          => 'Importar CSV de sensores',
  }.freeze

  def self.etiqueta(funcion) = ETIQUETAS[funcion.to_s] || funcion.to_s.humanize

  # USD por millón de tokens, por modelo. Se usa sólo para calcular el costo AL INSERTAR — una
  # vez guardado, `costo_usd` no se recalcula: si mañana cambia el precio, los registros viejos
  # tienen que seguir diciendo lo que costaron entonces.
  #
  # Las claves salen de `Ia::Modelos` a propósito: agregar un modelo sin su precio lo haría
  # cobrar al precio por defecto sin que nada falle.
  PRECIOS = {
    Ia::Modelos::RAZONA => { entrada: 3.0, salida: 15.0 },
    Ia::Modelos::RAPIDO => { entrada: 1.0, salida:  5.0 },
    'claude-haiku-4-5'  => { entrada: 1.0, salida:  5.0 }, # alias sin fecha, por si aparece guardado
  }.freeze

  # Modelo desconocido (uno nuevo que todavía no está en la tabla): se cobra al precio más caro
  # que conocemos en vez de a cero. Un costo estimado de más se nota y se corrige; uno de menos
  # pasa desapercibido y se factura mal.
  PRECIO_POR_DEFECTO = { entrada: 3.0, salida: 15.0 }.freeze

  validates :funcion, inclusion: { in: FUNCIONES }
  validates :modelo,  presence: true

  scope :recientes,  -> { order(created_at: :desc) }
  # OJO con `all_month`: sobre una Date devuelve un rango de DATES, y comparado contra un
  # timestamp corta a la medianoche del último día. El día 31 no contaba NADA de esa jornada —
  # el consumo salía de menos, el tope no se aplicaba y el cliente tenía créditos gratis un día
  # por mes. (`all_day` sobre una Date sí devuelve Times: ese no tiene el problema.)
  scope :del_mes,    ->(fecha = Time.zone.today) {
    where(created_at: fecha.beginning_of_month.beginning_of_day..fecha.end_of_month.end_of_day)
  }
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

  # ── Créditos ────────────────────────────────────────────────────────────────────────────
  #
  # Lo que ve la organización. Es el costo real convertido a una unidad propia, NO un número
  # aparte: si se tipeara en otro lado, un día dejaría de coincidir con lo que de verdad se
  # gasta y estaríamos vendiendo por debajo del costo sin enterarnos.
  #
  # Por qué créditos y no dólares: distintas funciones cuestan muy distinto (una importación de
  # plan de trabajo paga hasta 4.096 tokens de salida, un mapeo de CSV 512 — ocho veces menos),
  # así que contar "consultas" mide mal. Y mostrar dólares le expondría el costo al cliente.
  #
  # El valor está elegido para que un dictado ≈ 1 crédito, que es la unidad con la que la
  # persona piensa. Un dictado típico: ~1.400 tokens de prompt fijo leídos de caché (US$0,0004)
  # + ~600 de contexto (US$0,0018) + ~400 de salida (US$0,006) ≈ US$0,008.
  USD_POR_CREDITO = 0.01

  # Se redondea SIEMPRE para arriba: una llamada que costó algo nunca puede salir gratis, y el
  # error de redondeo tiene que quedar de nuestro lado, no del que factura.
  def self.creditos_de(costo_usd)
    c = costo_usd.to_f
    return 0 if c <= 0

    [(c / USD_POR_CREDITO).ceil, 1].max
  end

  def creditos = self.class.creditos_de(costo_usd)

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
