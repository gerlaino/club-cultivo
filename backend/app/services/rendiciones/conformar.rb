module Rendiciones
  # El repartidor dice si está de acuerdo con el monto que le ajustaron.
  #
  # NO es un candado: la plata ya entró al cajón cuando el receptor la contó. Esto es constancia
  # — que el que puso el número no sea el único que lo vio. Mientras no conforme, la rendición
  # aparece en la bandeja del admin, que es donde una diferencia de efectivo se resuelve: hablando.
  class Conformar
    Result = Struct.new(:ok, :rendicion, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(rendicion:, usuario:, conforme: true, notas: nil)
      @rendicion = rendicion
      @usuario   = usuario
      @conforme  = conforme
      @notas     = notas
    end

    def call
      return err('Esta rendición todavía no fue recibida') unless @rendicion&.recibida?
      return err('Sólo el repartidor conforma su rendición') unless @usuario.id == @rendicion.delivery_id
      return err('No hubo ajuste que conformar') if @rendicion.conforme.nil?

      @rendicion.update!(
        conforme: @conforme, conformada_at: Time.current,
        motivo_ajuste: [@rendicion.motivo_ajuste, (@notas.presence && "repartidor: #{@notas}")]
                       .compact.join(' · ').presence
      )
      Result.new(ok: true, rendicion: @rendicion)
    rescue ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)
  end
end
