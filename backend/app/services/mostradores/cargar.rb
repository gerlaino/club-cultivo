module Mostradores
  # EL ADMIN GOBIERNA LA MESA, DESDE DONDE ESTÉ.
  #
  # Sube y baja producto del mostrador cuando quiere: a las 7 de la mañana antes de que llegue
  # nadie, o desde el celular a media tarde porque se acabó algo. Ese es el punto entero del
  # módulo — que pueda delegar tranquilo y monitorear a distancia, sin tener que estar ahí.
  #
  # SIEMPRE CON MOTIVO. "Hay 300 g" sin historial es un número que apareció, y monitorear a
  # distancia sin historial es mirar una foto.
  #
  # Subir a la mesa APARTA, no descuenta: la fila `Stock` sigue siendo una sola con su ST-xx y su
  # QR, porque lo trazable sale del inventario por dispensación y nunca por cambiar de estante.
  # Y bajar de la mesa NO es un retiro a nombre de nadie: el producto sigue adentro de la
  # organización, sólo vuelve al depósito. Retiro es cuando algo SALE del club, y para eso está
  # la salida de stock con motivo.
  class Cargar
    Result = Struct.new(:ok, :items, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `cambios`: [{ stock_id:, cantidad: }] — `cantidad` es el TOTAL que tiene que quedar sobre
    # la mesa, no el delta. La pantalla es una tabla donde se escribe cuánto hay: pedirle al
    # usuario que calcule la diferencia sería pedirle que haga la cuenta que hace la máquina.
    def initialize(mostrador:, usuario:, cambios: [], motivo: nil)
      @mostrador = mostrador
      @usuario   = usuario
      @cambios   = Array(cambios).select { |c| c.respond_to?(:[]) && !c.is_a?(String) }
      @motivo    = motivo
      @club      = mostrador.club
    end

    def call
      return err('Indicá qué producto y cuánto') if @cambios.empty?
      return err('Escribí por qué se cambia la mesa') if @motivo.blank?

      tocados = []
      ActiveRecord::Base.transaction { @cambios.each { |c| tocados << aplicar!(c) } }
      Result.new(ok: true, items: tocados.compact)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    def aplicar!(datos)
      stock = buscar_stock!(datos[:stock_id] || datos['stock_id'])
      nueva = (datos[:cantidad] || datos['cantidad']).to_d
      raise ArgumentError, 'La cantidad no puede ser negativa' if nueva.negative?

      item  = @mostrador.item_de!(stock)
      delta = nueva - item.cantidad.to_d
      return item if delta.zero?

      # El techo de lo que se sube es lo LIBRE del depósito, que ya descuenta lo reservado a un
      # paciente, lo apartado a un evento y lo que esta misma mesa ya tiene arriba.
      if delta.positive? && delta > stock.cantidad_disponible_real.to_d
        raise ArgumentError,
              "No hay tanto de #{stock.etiqueta} en el depósito: quedan " \
              "#{stock.cantidad_disponible_real.round(2)} #{stock.unidad || 'g'} libres"
      end

      item.mover!(cantidad: delta, tipo: delta.positive? ? 'carga' : 'retiro',
                  usuario: @usuario, motivo: @motivo, turno: @mostrador.turno_abierto)
      item
    end

    def buscar_stock!(id)
      stock = @club.stocks.find_by(id: id)
      raise ArgumentError, 'Ese producto no existe' if stock.nil?
      raise ArgumentError, "#{stock.etiqueta} no está habilitado para dispensa" unless stock.apto_dispensa?
      unless stock.sede_id == @mostrador.sede_id
        raise ArgumentError, "#{stock.etiqueta} no está asignado a esta sede"
      end

      stock
    end
  end
end
