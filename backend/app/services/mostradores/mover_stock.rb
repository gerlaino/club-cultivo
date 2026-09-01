module Mostradores
  # Cargar mercadería del depósito a la mesa, o devolverla, con el turno ya abierto.
  #
  # Sacar del depósito es de administración, pero si a las 8 de la noche no hay ningún admin,
  # bloquear al dispensador es mandar pacientes a casa: la llave del depósito la tiene igual. Se
  # permite, se marca `sin_supervision` y cae en la bandeja del admin. Cuando el admin no está,
  # el sistema registra — no bloquea.
  #
  # Ni cargar ni devolver generan `StockMovimiento`: el gramo no salió de la organización ni
  # cambió de sede, sigue siendo la misma fila. Lo único que cambia es quién responde por él, y
  # ese rastro es el `TurnoMostradorMovimiento`.
  class MoverStock
    Result = Struct.new(:ok, :item, :error, keyword_init: true) do
      def ok? = ok
    end

    SUPERVISAN = %w[admin supervisor super_admin].freeze

    def self.cargar(**kwargs)   = new(**kwargs, tipo: 'carga').call
    def self.devolver(**kwargs) = new(**kwargs, tipo: 'devolucion').call

    def initialize(turno:, usuario:, cantidad:, tipo:, stock: nil, item: nil, notas: nil)
      @turno    = turno
      @usuario  = usuario
      @cantidad = cantidad.to_d
      @tipo     = tipo
      @stock    = stock
      @item     = item
      @notas    = notas
    end

    def call
      return err('El turno no está abierto')        unless @turno&.abierto?
      return err('La cantidad tiene que ser mayor a 0') if @cantidad <= 0

      item = @item || buscar_o_crear_item
      return err(item) if item.is_a?(String)

      ActiveRecord::Base.transaction do
        @tipo == 'carga' ? aplicar_carga!(item) : aplicar_devolucion!(item)
        item.movimientos.create!(club: @turno.club, usuario: @usuario, tipo: @tipo,
                                 cantidad: @cantidad, notas: @notas.presence,
                                 sin_supervision: sin_supervision?)
      end
      Result.new(ok: true, item: item.reload)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    # Un dispensador solo puede sacar del depósito, y queda marcado. Devolver no necesita marca:
    # devolver mercadería nunca es el problema.
    def sin_supervision? = @tipo == 'carga' && !SUPERVISAN.include?(@usuario.role)

    def buscar_o_crear_item
      return 'Indicá qué producto' if @stock.nil?
      return "#{@stock.etiqueta} no está habilitado para dispensa" unless @stock.apto_dispensa?
      return "#{@stock.etiqueta} no está asignado a esta sede" unless @stock.sede_id == @turno.mostrador.sede_id

      @turno.items.find_by(stock_id: @stock.id) ||
        @turno.items.create!(club: @turno.club, stock: @stock, cantidad_apertura: 0)
    end

    def aplicar_carga!(item)
      # El techo es lo LIBRE del depósito, que ya descuenta lo reservado a un paciente, lo
      # apartado a un evento y lo que este mismo mostrador tiene arriba.
      libre = item.stock.cantidad_disponible_real.to_d
      if @cantidad > libre
        raise ArgumentError,
              "No hay tanto de #{item.stock.etiqueta} en el depósito: quedan #{libre.round(2)} #{item.stock.unidad || 'g'}"
      end

      item.update!(cantidad_repuesta: item.cantidad_repuesta.to_d + @cantidad)
    end

    def aplicar_devolucion!(item)
      if @cantidad > item.esperado
        raise ArgumentError,
              "No hay tanto de #{item.stock.etiqueta} sobre la mesa: hay #{item.esperado.round(2)} #{item.stock.unidad || 'g'}"
      end

      item.update!(cantidad_devuelta: item.cantidad_devuelta.to_d + @cantidad)
    end
  end
end
