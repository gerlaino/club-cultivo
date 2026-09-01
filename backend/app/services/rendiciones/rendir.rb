module Rendiciones
  # El repartidor entrega su recaudación y elige a quién.
  #
  # El monto NO lo escribe él: es la suma de los cobros que ya cargó en cada puerta. Dejarlo
  # declarar un número sería pedirle que se acuerde, y el sistema ya lo sabe con precisión.
  class Rendir
    Result = Struct.new(:ok, :rendicion, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(delivery:, club:, receptor:)
      @delivery = delivery
      @club     = club
      @receptor = receptor
    end

    def call
      return err('Elegí a quién le rendís la caja') if @receptor.nil?
      return err('No podés rendirte la caja a vos mismo') if @receptor.id == @delivery.id
      return err('Esa persona no es de la organización') unless @receptor.club_id == @club.id
      unless RECIBEN.include?(@receptor.role)
        return err('La caja se le rinde a quien responde por ella: administración o el mostrador.')
      end

      pendiente = RendicionCaja.pendientes.find_by(delivery_id: @delivery.id)
      return err('Ya tenés una rendición esperando que la reciban') if pendiente

      cobros    = cobros_en_transito
      paquetes  = self.class.devoluciones_de(@delivery, @club)
      if cobros.empty? && paquetes.empty?
        return err('No tenés efectivo ni paquetes pendientes de rendir')
      end

      rendicion = nil
      ActiveRecord::Base.transaction do
        rendicion = RendicionCaja.create!(
          club: @club, delivery: @delivery, receptor: @receptor, estado: 'pendiente',
          monto_declarado_ars: cobros.sum { |c| c.monto_ars.to_d },
          cobros_count: cobros.size, rendida_at: Time.current
        )
        # Se atan ACÁ, no al recibir: si el repartidor sigue entregando mientras espera, esos
        # cobros nuevos son de la próxima rendición y no de esta — que ya tiene un monto declarado
        # que alguien va a contra-contar.
        Cobro.where(id: cobros.map(&:id)).update_all(rendicion_caja_id: rendicion.id)
      end
      Result.new(ok: true, rendicion: rendicion)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      err(e.message)
    end

    # Los paquetes que el repartidor trae de vuelta sin entregar. Al recibir la rendición se
    # desarman TODOS: no se elige. Es una decisión de calidad — un paquete que estuvo en la calle
    # y volvió no se guarda armado esperando otro intento.
    def self.devoluciones_de(delivery, club)
      Dispensacion.joins(:paciente)
                  .where(pacientes: { club_id: club.id })
                  .where(delivery_id: delivery.id, estado_envio: 'fallido')
                  .includes(:paciente, :stock).order(:fallido_at)
    end

    # A quién se le puede rendir: quien responde por la caja o quien la atiende.
    RECIBEN = %w[admin supervisor dispensador].freeze

    def self.receptores_de(club)
      club.users.where(role: RECIBEN).order(:first_name)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    def cobros_en_transito
      Cobro.efectivo_en_transito.del_delivery(@delivery.id)
           .where(club_id: @club.id, rendicion_caja_id: nil)
           .includes(dispensacion: :paciente).to_a
    end
  end
end
