module Mostradores
  # ABRIR LA CAJA DEL MOSTRADOR: quien atiende cuenta lo que hay y arranca.
  #
  # Ya no se "abre el mostrador" poniendo mercadería —eso lo hace el admin cuando quiere, y el
  # contenido de la mesa es permanente—. Acá se hace lo único que corresponde a quien va a
  # atender: **pesar lo que encuentra y contar la plata**.
  #
  # NO BLOQUEA POR DIFERENCIA. Si lo que cuenta no coincide con lo que dice el sistema, pone lo
  # que contó y abre igual: la diferencia queda anotada y la ve el admin. Bloquearlo dejaría el
  # mostrador cerrado a las 8 de la mañana esperando a alguien que no está — que es exactamente
  # lo que este módulo existe para evitar. Si el admin se olvidó de contar la primera vez, se
  # arranca igual.
  #
  # El conteo de apertura reemplaza a la vieja "recepción" separada: era la misma verificación
  # pedida dos veces, con un botón de confirmar que nadie miraba.
  class AbrirCaja
    Result = Struct.new(:ok, :turno, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `conteos`: [{ stock_id:, contado: }] — lo que la persona pesó, producto por producto.
    # `efectivo_contado_ars`: lo que hay en el cajón. Si viene nil, se toma lo que dice el
    # sistema (el fondo que quedó del turno anterior).
    def initialize(mostrador:, usuario:, conteos: [], efectivo_contado_ars: nil, notas: nil)
      @mostrador = mostrador
      @usuario   = usuario
      @conteos   = Array(conteos).select { |c| c.respond_to?(:[]) && !c.is_a?(String) }
      @efectivo  = efectivo_contado_ars
      @notas     = notas
      @club      = mostrador.club
    end

    def call
      return err('Ya hay una caja abierta en este mostrador') if @mostrador.turno_abierto

      turno = nil
      ActiveRecord::Base.transaction do
        turno = TurnoMostrador.create!(
          club: @club, mostrador: @mostrador, caja_turno: caja,
          turno_anterior: ultimo_cerrado, estado: 'abierto',
          abierto_por: @usuario, abierto_at: Time.current,
          notas_apertura: observaciones
        )
        registrar_conteos!(turno)
        ajustar_efectivo!(turno)
      end
      Result.new(ok: true, turno: turno.reload)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    def ultimo_cerrado
      @ultimo_cerrado ||= @mostrador.turno_mostradores.cerrados.order(cerrado_at: :desc).first
    end

    def sobre_la_mesa = @sobre_la_mesa ||= @mostrador.sobre_la_mesa.to_a

    def contado_por_stock
      @contado_por_stock ||= @conteos.each_with_object({}) do |c, acc|
        id = (c[:stock_id] || c['stock_id']).to_i
        acc[id] = (c[:contado] || c['contado'])
      end
    end

    # Cada producto de la mesa queda con LO QUE DECÍA el sistema y LO QUE SE CONTÓ. Los dos: sin
    # el esperado escrito, mañana no hay contra qué comparar; sin lo contado, el arqueo de la
    # noche mediría contra un número que nadie verificó.
    #
    # Y si lo contado difiere, LA MESA SE CORRIGE: lo que hay es lo que se contó. Dejar el número
    # viejo obligaría a arrastrar la misma diferencia toda la jornada y volver a explicarla al
    # cerrar.
    def registrar_conteos!(turno)
      sobre_la_mesa.each do |mi|
        esperado = mi.cantidad.to_d
        crudo    = contado_por_stock[mi.stock_id]
        contado  = crudo.nil? || crudo.to_s.strip.empty? ? esperado : crudo.to_d
        raise ArgumentError, 'La cantidad contada no puede ser negativa' if contado.negative?

        # `esperado_apertura` y no `cantidad_heredada`: es el mismo número, y escribirlo en dos
        # columnas es exactamente de donde salieron los bugs de doble descuento de este módulo.
        # La columna vieja se queda con lo de los turnos anteriores y no se escribe más.
        turno.items.create!(club: @club, stock_id: mi.stock_id,
                            esperado_apertura: esperado, cantidad_apertura: contado)

        dif = contado - esperado
        next if dif.zero?

        # La mesa pasa a tener lo que se contó. NO toca el inventario real: acá todavía no se
        # sabe si faltó de verdad o si el admin declaró de más, y el producto puede estar en el
        # depósito. Lo que sí queda es el rastro, con nombre y hora.
        mi.mover!(cantidad: dif, tipo: 'ajuste', usuario: @usuario, turno: turno,
                  motivo: "Conteo de apertura de #{@usuario.nombre_completo}")
      end
    end

    # Lo que la persona anota al abrir: las diferencias, en texto, para que el admin las lea sin
    # tener que reconstruirlas.
    def observaciones
      difs = sobre_la_mesa.filter_map do |mi|
        crudo = contado_por_stock[mi.stock_id]
        next if crudo.nil? || crudo.to_s.strip.empty?

        dif = crudo.to_d - mi.cantidad.to_d
        next if dif.zero?

        "#{mi.stock&.etiqueta}: contó #{crudo.to_d.round(2)} y había #{mi.cantidad.to_d.round(2)}"
      end
      [@notas.presence, difs.presence&.join(' · ')].compact.join(' · ').presence
    end

    # La caja de plata. Si ya hay una abierta se REUSA: dos cajas activas sobre el mismo cajón
    # parten el arqueo en dos por la misma plata.
    #
    # SIEMPRE HAY UNA. El botón no exige el campo —no bloquea por diferencia, ni siquiera por
    # "no contaste"— porque casi siempre hay algo de dónde heredar: el fondo del último cierre.
    # Pero el PRIMER día no hay ningún cierre anterior, y si tampoco se escribió nada, `fondo`
    # da `nil`. Devolverlo así abría el turno igual —se puede dispensar— pero SIN caja: lo
    # cobrado en efectivo no tendría dónde caer, y esa plata desaparecería del arqueo de esa
    # noche sin que nadie se enterara hasta contarla. Mejor un error claro que un cajón que no
    # existe.
    def caja
      abierta = @mostrador.caja_abierta
      return abierta if abierta

      fondo = @efectivo.nil? ? fondo_heredado : @efectivo.to_d
      if fondo.nil?
        raise ArgumentError,
              'No hay ningún cierre anterior del que heredar el fondo: contá el efectivo del cajón.'
      end
      raise ArgumentError, 'El efectivo contado no puede ser negativo' if fondo.negative?

      CajaTurno.create!(club: @club, sede: @mostrador.sede, punto: @mostrador,
                        abierta_por: @usuario, monto_inicial_ars: fondo,
                        abierta_at: Time.current)
    end

    # Si la caja venía abierta y lo contado no coincide con lo que dice, el fondo pasa a ser LO
    # CONTADO —es lo que hay— y la diferencia se asienta con quién la detectó. Sin corregirlo, el
    # cierre volvería a encontrar la misma diferencia y la contaría dos veces.
    #
    # A diferencia del stock, acá la diferencia SÍ es una pérdida real: los gramos que faltan
    # pueden estar en el depósito, pero los pesos que faltan no están en ningún lado.
    def ajustar_efectivo!(turno)
      c = turno.caja_turno
      return if c.nil? || @efectivo.nil? || @efectivo.to_s.strip.empty?

      dif = @efectivo.to_d - c.efectivo_esperado_ars.to_d
      return if dif.abs < 0.01

      c.update!(monto_inicial_ars: c.monto_inicial_ars.to_d + dif)
      c.movimientos_contables.create!(
        club: @club, sede_id: c.sede_id, created_by: @usuario,
        tipo: dif.negative? ? 'egreso' : 'ingreso', categoria: 'diferencia_caja',
        descripcion: "#{dif.negative? ? 'Faltante' : 'Sobrante'} al abrir la caja — " \
                     "#{@usuario.nombre_completo}",
        monto_ars: dif.abs, fecha: Time.zone.today,
        pagado: true, medio_pago: 'efectivo', comprobante_tipo: 'sin_comprobante'
      )
    end

    def fondo_heredado
      @mostrador.caja_turnos.cerradas.order(cerrada_at: :desc).first&.fondo_remanente_ars
    end
  end
end
