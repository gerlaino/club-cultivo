module Bar
  # Vende N entradas de un tipo, de forma atómica: valida el cupo, crea las entradas (con su
  # código para el QR) y actualiza el ingreso agregado del tipo en el libro.
  #
  #   Bar::VenderEntradas.new(tipo, actor, cantidad: 3, comprador: 'Rocío').call
  #
  # Devuelve el array de entradas creadas. Lanza ArgumentError si no hay cupo.
  class VenderEntradas
    def initialize(tipo, actor, cantidad:, comprador: nil)
      @tipo      = tipo
      @actor     = actor
      @cantidad  = cantidad.to_i
      @comprador = comprador
    end

    def call
      raise ArgumentError, 'Cantidad inválida' if @cantidad <= 0

      disp = @tipo.disponibles
      raise ArgumentError, "Solo quedan #{disp} entradas de #{@tipo.nombre}" if disp && @cantidad > disp

      # Tope por AFORO del evento (además del cupo por tipo): no se venden más entradas que
      # lugares tiene el evento.
      evento = @tipo.evento_bar
      aforo_disp = evento.aforo_disponible
      raise ArgumentError, "Se alcanzó el aforo del evento (#{evento.aforo}). Quedan #{aforo_disp} lugares." if aforo_disp && @cantidad > aforo_disp

      ActiveRecord::Base.transaction do
        entradas = Array.new(@cantidad) do
          @tipo.entradas.create!(
            club: @tipo.club, evento_bar: @tipo.evento_bar, created_by: @actor,
            comprador: @comprador, precio_ars: @tipo.precio_ars, estado: 'valida'
          )
        end
        @tipo.sincronizar_ingreso!(@actor)
        entradas
      end
    end
  end
end
