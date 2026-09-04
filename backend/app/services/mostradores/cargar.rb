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
  #
  # SALVO QUE SE DECLARE MERMA. Bajar 12 g porque se perdieron y que vuelvan al depósito es el
  # inventario mintiendo: esos gramos quedan contados como existentes y la pérdida no se mide en
  # ningún lado. Por eso cada línea que baja dice a dónde va (ver `destino`).
  class Cargar
    Result = Struct.new(:ok, :items, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `cambios`: [{ stock_id:, cantidad:, destino: }] — `cantidad` es el TOTAL que tiene que
    # quedar sobre la mesa, no el delta. La pantalla es una tabla donde se escribe cuánto hay:
    # pedirle al usuario que calcule la diferencia sería pedirle que haga la cuenta que hace la
    # máquina.
    #
    # `destino` sólo aplica a lo que BAJA: 'deposito' (por defecto, vuelve al inventario) o
    # 'merma' (se perdió y sale del inventario). Va por línea y no por tanda porque mezclar es lo
    # cotidiano —se reponen tres productos y de paso se declara uno que se rompió—, y obligar a
    # partir la operación en dos es pedir algo que nadie hace.
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

      # BAJAR NO SIEMPRE ES "VUELVE AL DEPÓSITO".
      #
      # Con `destino: 'merma'`, lo que baja no vuelve a ningún lado: se perdió, se rompió o se
      # consumió. Sin esta distinción, esos gramos quedaban contados como existentes en el
      # depósito —el inventario mintiendo, la merma sin medir— y el informe de Pérdidas no se
      # enteraba nunca.
      #
      # No choca con "el ajuste del arqueo NUNCA es merma": aquella regla existe porque un CONTEO
      # no sabe qué pasó (lo que falta puede estar en el depósito). Acá lo declara una persona.
      if delta.negative? && merma?(datos)
        item.mover!(cantidad: delta, tipo: 'ajuste', usuario: @usuario,
                    motivo: "Merma — #{@motivo}", turno: @mostrador.turno_abierto)
        registrar_merma!(stock, delta.abs)
      else
        item.mover!(cantidad: delta, tipo: delta.positive? ? 'carga' : 'retiro',
                    usuario: @usuario, motivo: @motivo, turno: @mostrador.turno_abierto)
      end
      item
    end

    def merma?(datos)
      (datos[:destino] || datos['destino']).to_s == 'merma'
    end

    # Sale del inventario de verdad, como `merma` y no como `ajuste`: el informe de Pérdidas
    # cuenta merma, y es exactamente lo que esto es. Un `ajuste` diría "no cuadró", que no es lo
    # mismo que "se perdió" — y para un auditor la diferencia importa.
    def registrar_merma!(stock, cantidad)
      stock.with_lock do
        if cantidad > stock.cantidad.to_d
          raise ArgumentError,
                "No se puede declarar más merma que lo que hay: #{stock.etiqueta} tiene " \
                "#{stock.cantidad.round(2)} #{stock.unidad || 'g'}"
        end

        stock.update!(cantidad: stock.cantidad.to_d - cantidad)
        stock.stock_movimientos.create!(
          tipo: 'merma', gramos: -cantidad, usuario: @usuario,
          turno_mostrador: @mostrador.turno_abierto,
          notas: "Merma declarada en el mostrador — #{@motivo}",
        )
      end
      stock.reload.marcar_agotado_si_vacio!(usuario: @usuario)
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
