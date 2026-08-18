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
          repreguntas: ['¿Qué genética me rinde mejor?', '¿Cuál me ocupa menos la sala?'],
        },
        'rendimiento_por_genetica' => {
          clase: RendimientoPorGenetica,
          descripcion: 'Cuánto rindió realmente cada genética en esta organización: gramos por ' \
                       'planta y gramos por planta por semana de ciclo. Usala para "¿qué ' \
                       'genética conviene?", "¿cuál rinde más?", "¿qué planto?".',
          repreguntas: ['¿Cuál me ocupa menos la sala?', '¿Cuánto me cuesta el gramo?'],
        },
        'perdidas_por_motivo' => {
          clase: PerdidasPorMotivo,
          descripcion: 'Cuántas plantas se descartan y por qué (no prendió, plaga, enfermedad, ' \
                       'macho, estrés…), en total y por genética. Usala para "¿qué se me muere?", ' \
                       '"¿por qué pierdo plantas?", "¿qué genética aguanta menos?".',
          repreguntas: ['¿Qué genética me rinde mejor?', '¿Cuánto me cuesta el gramo?'],
        },
        'costo_por_genetica' => {
          clase: CostoPorGenetica,
          descripcion: 'Cuánto cuesta el gramo producido, por genética, sobre los lotes que ' \
                       'tienen el costo cargado. Usala para "¿cuánto me cuesta el gramo?", ' \
                       '"¿qué genética me sale más barata?", "¿cuánto cobro?".',
          repreguntas: ['¿Qué genética me rinde mejor?', '¿Qué se me muere y por qué?'],
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

      # Qué más se puede preguntar después de esta respuesta.
      #
      # Son fijas por consulta y no las inventa el modelo, a propósito: cada botón tiene que caer
      # en algo que el sistema efectivamente puede contestar. Una sugerencia que después no se
      # puede responder es peor que no sugerir nada — el problema de estas herramientas no es que
      # contesten mal, es que no se sabe qué saben contestar.
      def repreguntas(claves)
        Array(claves).flat_map { |c| DISPONIBLES.dig(c.to_s, :repreguntas).to_a }.uniq
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
