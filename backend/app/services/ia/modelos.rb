module Ia
  # Qué modelo usa cada función, en un solo lugar.
  #
  # Estaba escrito a mano en cuatro archivos —y dos veces dentro del mismo controller del
  # asistente, una como constante y otra como literal en el body del request—. Es la misma regla
  # en varios lados: el día que se cambie de modelo, el que quede sin actualizar sigue llamando
  # al viejo sin que nada falle, y el costo se registra contra un precio que no corresponde.
  #
  # Cada nombre que entre acá tiene que tener su fila en `IaLlamada::PRECIOS`, si no el costo se
  # calcula al precio por defecto y la facturación queda mal en silencio. Hay un spec que lo
  # verifica.
  module Modelos
    # Razonamiento: interpretar lo que dictó una persona, analizar, planificar.
    RAZONA = 'claude-sonnet-4-6'.freeze

    # Mecánico: mapear columnas de un CSV a campos. No necesita criterio, necesita ser barato.
    RAPIDO = 'claude-haiku-4-5-20251001'.freeze

    TODOS = [RAZONA, RAPIDO].freeze
  end
end
