module Ia
  module Consultas
    # De dónde saca el chatbot los datos para contestar. Una consulta por pregunta, cerrada y
    # parametrizada — nunca SQL que escriba el modelo contra una base multi-tenant con datos de
    # salud.
    #
    # Lo importante de esta clase es el GUARD, y dónde vive: **si no hay datos suficientes, el
    # modelo no ve los números**. No se le pide en el prompt que sea prudente —un modelo con dos
    # filas escribe un párrafo igual de convencido que con doscientas, y "pocos datos" lo
    # interpretaría él—. Se le manda "todavía no hay con qué" y no hay nada sobre lo que opinar.
    #
    # Y no es una pared: cuando no alcanza, la respuesta dice QUÉ falta y QUÉ sí se puede
    # contestar. Así el guard deja de ser un freno y le enseña a la organización qué cargar para
    # que la herramienta le sirva.
    class Base
      # `suficiente` false ⇒ `datos` va vacío A PROPÓSITO. Es la garantía de la clase: no existe
      # un camino en el que el modelo reciba datos que no alcanzan.
      Resultado = Struct.new(:suficiente, :datos, :falta, :disponible, keyword_init: true) do
        def suficiente? = !!suficiente

        # Lo que efectivamente viaja al modelo.
        def to_h
          return { suficiente: false, falta: falta, disponible: disponible }.compact unless suficiente?

          { suficiente: true, datos: datos }
        end
      end

      def initialize(club)
        @club = club
      end

      # Cada consulta implementa esto y devuelve un `Resultado`.
      def resolver(**)
        raise NotImplementedError
      end

      # Cómo se llama la consulta para el modelo y para el log.
      def self.clave = name.demodulize.underscore

      private

      attr_reader :club

      def suficiente(datos)  = Resultado.new(suficiente: true, datos: datos)
      def insuficiente(falta, disponible: nil)
        Resultado.new(suficiente: false, falta: falta, disponible: disponible)
      end
    end
  end
end
