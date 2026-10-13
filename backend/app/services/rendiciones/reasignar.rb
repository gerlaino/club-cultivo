module Rendiciones
  # Administración cambia A QUIÉN va dirigida una rendición que nadie recibe.
  #
  # Sólo la recibe la persona a la que se la rindieron (`RendicionesController#serialize`,
  # `puedo_recibir`). Si esa persona no la recibe —se fue, no está, se olvidó—, la plata queda
  # en el aire: el panel avisa «entregada sin recibir» y no había nadie que pudiera destrabarla
  # (Germán, 13-oct-2026, una de Mitocondria esperaba desde el 17-sep).
  #
  # No se recibe en nombre de otro: se REASIGNA, y el nuevo receptor la cuenta. La regla de la
  # rendición sigue intacta: el que cuenta es el que tiene la plata en la mano. El cambio queda en
  # el rastro (`RendicionCaja` audita `receptor_id`).
  class Reasignar
    Result = Struct.new(:ok, :rendicion, :error, keyword_init: true) do
      def ok? = ok
    end

    GESTIONAN = %w[admin supervisor super_admin].freeze

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(rendicion:, receptor:, por:)
      @rendicion = rendicion
      @receptor  = receptor
      @por       = por
    end

    def call
      return err('Sólo administración reasigna una rendición') unless GESTIONAN.include?(@por.role)
      return err('Esa rendición ya se recibió') unless @rendicion.pendiente?
      return err('Elegí a quién se la reasignás') if @receptor.nil?
      return err('Ya está dirigida a esa persona') if @receptor.id == @rendicion.receptor_id
      return err('No se le puede rendir la caja al mismo repartidor') if @receptor.id == @rendicion.delivery_id
      # Las mismas personas a las que el repartidor puede rendir: una sola regla.
      unless Rendir.receptores_de(@rendicion.club).exists?(id: @receptor.id)
        return err('La caja se le rinde a quien responde por ella: administración o el mostrador.')
      end

      @rendicion.update!(receptor: @receptor)
      Result.new(ok: true, rendicion: @rendicion)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)
  end
end
