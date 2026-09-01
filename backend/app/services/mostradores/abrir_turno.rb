module Mostradores
  # Abrir el mostrador: la plata y la mercadería, en un solo gesto.
  #
  # Se abre y se cierra desde la misma vista, y se puede hacer varias veces por día — dos
  # dispensadores no atienden a la vez, se turnan, y cerrar-y-reabrir ES el arqueo. Por eso NO
  # hay relevo con firma cruzada: el que tuvo la mercadería es el que la contó. Pedirle a quien
  # entra que vuelva a contar lo que se contó hace diez horas termina en un botón de "confirmar"
  # que nadie mira, y en una firma que después se usa para acusar a alguien que nunca contó.
  #
  # Lo que SÍ hay es herencia: el turno arranca con lo que dejó el anterior, y el que abre puede
  # corregir el número si el frasco no da. Eso es un campo editable, no una ceremonia — y si lo
  # tocó, queda registrado (`cantidad_heredada` vs `cantidad_apertura`).
  #
  # La mercadería se APARTA, no se descuenta: es la mecánica del apartado de un evento, con otro
  # destinatario. La fila `Stock` sigue siendo una sola con su ST-xx y su QR, porque lo trazable
  # sale del inventario por dispensación y nunca por cambiar de mesa.
  class AbrirTurno
    Result = Struct.new(:ok, :turno, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `items`: [{ stock_id:, cantidad: }]. `monto_inicial_ars` es el fondo de caja; nil = no se
    # toca la caja de plata (por ejemplo, ya hay una abierta de un turno anterior).
    def initialize(mostrador:, usuario:, items: [], monto_inicial_ars: nil, notas: nil)
      @mostrador = mostrador
      @usuario   = usuario
      # Una lista vacía viaja form-encoded como "" y llega como [""]: sin este filtro reventaba
      # con un TypeError en vez de simplemente no cargar nada.
      @items     = Array(items).select { |i| i.respond_to?(:[]) && !i.is_a?(String) }
      @fondo     = monto_inicial_ars
      @notas     = notas
      @club      = mostrador.club
    end

    def call
      return err('Ya hay un turno abierto en este mostrador') if @mostrador.turno_abierto

      turno = nil
      ActiveRecord::Base.transaction do
        # Si lo abre el que va a atender, queda confirmado en el acto: cargó la mesa él mismo,
        # no hay entrega que firmar. La firma existe para cuando lo carga el admin y lo recibe
        # otro — ahí sí hay dos personas y una diferencia que puede ser de cualquiera de las dos.
        recibe = Dispensacion::ROLES_DEL_MOSTRADOR.include?(@usuario.role)

        turno = TurnoMostrador.create!(
          club: @club, mostrador: @mostrador, caja_turno: caja,
          turno_anterior: ultimo_cerrado, estado: 'abierto',
          abierto_por: @usuario, abierto_at: Time.current, notas_apertura: @notas.presence,
          confirmado_por: (@usuario if recibe), confirmado_at: (Time.current if recibe)
        )
        @items.each { |attrs| crear_item!(turno, attrs) }
      end
      Result.new(ok: true, turno: turno)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    def ultimo_cerrado
      @ultimo_cerrado ||= @mostrador.turno_mostradores.cerrados.order(cerrado_at: :desc).first
    end

    # Lo que dejó el turno anterior, por stock. Es lo que se hereda, y el backend lo calcula solo:
    # que el número de partida lo mande el cliente sería dejar que cualquiera declare con cuánto
    # arranca y borre la diferencia de un plumazo.
    def heredado
      @heredado ||= begin
        return {} if ultimo_cerrado.nil?

        ultimo_cerrado.items.each_with_object({}) do |it, acc|
          acc[it.stock_id] = it.cantidad_cierre
        end
      end
    end

    # La caja de plata del turno. Si ya hay una abierta en este mostrador se REUSA en vez de
    # abrir otra: puede pasar que la caja quedara abierta de antes, y dos cajas activas sobre el
    # mismo cajón harían que el arqueo se parta en dos por la misma plata.
    def caja
      abierta = @mostrador.caja_abierta
      return abierta if abierta

      fondo = @fondo.nil? ? fondo_heredado : @fondo.to_d
      return nil if fondo.nil?

      CajaTurno.create!(club: @club, sede: @mostrador.sede, punto: @mostrador,
                        abierta_por: @usuario, monto_inicial_ars: fondo,
                        abierta_at: Time.current)
    end

    # Lo que quedó en el cajón anoche después de retirar la recaudación. El fondo se hereda igual
    # que los gramos: quien abre no elige con cuánto arranca.
    def fondo_heredado
      @mostrador.caja_turnos.cerradas.order(cerrada_at: :desc).first&.fondo_remanente_ars
    end

    def crear_item!(turno, attrs)
      stock    = buscar_stock!(attrs[:stock_id] || attrs['stock_id'])
      cantidad = (attrs[:cantidad] || attrs['cantidad']).to_d
      raise ArgumentError, "La cantidad de #{stock.etiqueta} tiene que ser mayor a 0" if cantidad <= 0

      # El techo es el disponible LIBRE: lo reservado para un paciente y lo apartado para un
      # evento no se puede poner sobre la mesa, aunque esté en el mismo frasco.
      libre = stock.cantidad_disponible_real.to_d
      if cantidad > libre
        raise ArgumentError,
              "No hay tanto de #{stock.etiqueta}: quedan #{libre.round(2)} #{stock.unidad || 'g'} libres"
      end

      turno.items.create!(club: @club, stock: stock, cantidad_apertura: cantidad,
                          cantidad_heredada: heredado[stock.id])
    end

    def buscar_stock!(id)
      stock = @club.stocks.find_by(id: id)
      raise ArgumentError, 'Ese producto no existe en la organización' if stock.nil?
      raise ArgumentError, "#{stock.etiqueta} no está habilitado para dispensa" unless stock.apto_dispensa?
      unless stock.sede_id == @mostrador.sede_id
        raise ArgumentError, "#{stock.etiqueta} no está asignado a esta sede"
      end

      stock
    end
  end
end
