module Ariccame
  # Transmite un registro a ARICCAME/ANMAT. La integración REAL con la API de ANMAT
  # todavía no existe (no tenemos credenciales/endpoint). Por ahora SIMULA el envío:
  # marca enviado → confirmado con un código generado, dejando todo el flujo de estados
  # (pendiente → enviado → confirmado / error, con reintentos) listo para cuando exista
  # la API. Para activar el envío real: setear ARICCAME_SIMULAR=false e implementar el
  # POST a ANMAT en `enviar_real` con `@registro.payload`.
  class Transmisor
    Result = Struct.new(:ok, :estado, :error, keyword_init: true) do
      def ok? = ok
    end

    MAX_INTENTOS = 3

    def self.simular? = ENV.fetch('ARICCAME_SIMULAR', 'true') == 'true'
    def self.call(registro) = new(registro).call

    def initialize(registro)
      @registro = registro
    end

    def call
      return Result.new(ok: false, error: 'El registro ya está confirmado') if @registro.estado == 'confirmado'
      if @registro.estado == 'error' && @registro.intentos >= MAX_INTENTOS
        return Result.new(ok: false, error: "Sin más reintentos (máx #{MAX_INTENTOS})")
      end

      codigo, respuesta = self.class.simular? ? simular_envio : enviar_real

      @registro.marcar_enviado!(codigo: codigo)
      @registro.marcar_confirmado!(codigo: codigo, respuesta: respuesta)
      Result.new(ok: true, estado: 'confirmado')
    rescue => e
      @registro.marcar_error!(mensaje: e.message)
      Result.new(ok: false, estado: 'error', error: e.message)
    end

    private

    # Simulación: un código tipo ANMAT y respuesta marcada como simulada.
    def simular_envio
      codigo = "SIM-#{Time.current.strftime('%Y%m')}-#{format('%06d', @registro.id)}"
      [codigo, { simulado: true, mensaje: 'Aceptado (simulado, sin envío real a ANMAT)' }]
    end

    # TODO: POST real a la API de ANMAT con @registro.payload cuando haya credenciales.
    def enviar_real
      raise 'Integración real con ANMAT no configurada (ARICCAME_SIMULAR=false sin API)'
    end
  end
end
