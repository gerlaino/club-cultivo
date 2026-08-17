module Ia
  module Consultas
    # De qué puede hablar el chatbot, en un solo lugar.
    #
    # El modelo NO escribe SQL: elige de esta lista cerrada, y cada consulta corre atada al club
    # del usuario. Por eso el aislamiento entre organizaciones sale gratis — aunque el modelo
    # quisiera pedir datos de otro club, no hay forma de expresarlo.
    #
    # Agregar una pregunta es agregar una fila acá y su clase. Si mañana hay que sacar una, se
    # saca de acá y desaparece de todos lados: no hay una segunda lista en el prompt que se pueda
    # desincronizar.
    module Registro
      module_function

      DISPONIBLES = {
        'produccion_proxima' => {
          clase: ProduccionProxima,
          descripcion: 'Qué se va a cosechar y cuántos gramos se esperan de los lotes que están ' \
                       'hoy en floración o en post-cosecha. Usala para "¿voy a tener producto?", ' \
                       '"¿cuándo cosecho?", "¿cuánto va a salir?".',
        },
        'rendimiento_por_genetica' => {
          clase: RendimientoPorGenetica,
          descripcion: 'Cuánto rindió realmente cada genética en esta organización: gramos por ' \
                       'planta y gramos por planta por semana de ciclo. Usala para "¿qué ' \
                       'genética conviene?", "¿cuál rinde más?", "¿qué planto?".',
        },
      }.freeze

      # Formato de herramientas de la API. `input_schema` vacío porque ninguna consulta toma
      # parámetros todavía: cuando alguna los tome, van acá y se validan en la consulta, nunca
      # se interpolan crudos.
      def herramientas
        DISPONIBLES.map do |clave, meta|
          {
            name: clave,
            description: meta[:descripcion],
            input_schema: { type: 'object', properties: {}, required: [] },
          }
        end
      end

      # Corre una consulta por su clave. Devuelve nil si el modelo inventó un nombre — no se
      # levanta una excepción por eso: que alucine una herramienta no puede tumbar la respuesta.
      def resolver(clave, club)
        meta = DISPONIBLES[clave.to_s]
        return nil if meta.nil?

        meta[:clase].new(club).resolver.to_h
      rescue StandardError => e
        Rails.logger.error("[chatbot] falló la consulta #{clave}: #{e.class} #{e.message}")
        { suficiente: false, falta: 'no se pudo consultar ese dato ahora mismo' }
      end
    end
  end
end
