module Mostradores
  # CERRAR LA CAJA: se cuenta el stock y la plata, y se muestra la diferencia.
  #
  # Es el mismo gesto para el arqueo del mediodía y para el cambio de turno: cierra uno, y el que
  # sigue abre contando lo que dice que hay. Cerrar y volver a abrir ES el arqueo.
  #
  # LA DIFERENCIA SE MUESTRA, NO BLOQUEA. La merma es inevitable y no es culpa de nadie: se mide
  # para que la organización sepa cuánta hay y dónde, y encuentre sus cuellos de botella. Queda
  # anotada, la ve el admin —en el mostrador y en la ficha de la persona— y el turno cierra.
  #
  # CIERRA EN EL ACTO, sin esperar al admin: si quedara pendiente de su visto bueno, a las once
  # de la noche el mostrador está bloqueado y el que abre mañana no arranca.
  #
  # Los dos arqueos son INDEPENDIENTES y sólo el efectivo los cruza:
  #   • mercadería → todo lo que está sobre la mesa, sin mirar el medio de pago. Una dispensa a
  #     cuenta corriente sacó el producto igual, y una con envío también.
  #   • plata      → sólo lo que entró al cajón. La cuenta corriente es deuda registrada, y el
  #     efectivo que cobró el repartidor está en su bolsillo hasta que rinde.
  class CerrarCaja
    Result = Struct.new(:ok, :turno, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `conteos`: [{ stock_id:, contado: }] — uno por producto que haya sobre la mesa.
    def initialize(turno:, usuario:, conteos: [], efectivo_contado_ars: nil,
                   fondo_siguiente_ars: nil, retirado_por: nil, notas: nil)
      @turno    = turno
      @usuario  = usuario
      @conteos  = Array(conteos).select { |c| c.respond_to?(:[]) && !c.is_a?(String) }
      @efectivo = efectivo_contado_ars
      @fondo    = fondo_siguiente_ars
      @retirado_por = retirado_por
      @notas    = notas
      @mostrador = turno&.mostrador
    end

    def call
      return err('La caja del mostrador no está abierta') unless @turno&.abierto?

      faltan = validar_conteos
      return err(faltan) if faltan

      ActiveRecord::Base.transaction do
        aplicar_conteos!
        @turno.update!(estado: 'cerrado', cerrado_por: @usuario, cerrado_at: Time.current,
                       notas_cierre: @notas.presence)
        cerrar_la_caja!
      end
      Result.new(ok: true, turno: @turno.reload)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    def sobre_la_mesa = @sobre_la_mesa ||= @mostrador.sobre_la_mesa.to_a

    def contado_por_stock
      @contado_por_stock ||= @conteos.each_with_object({}) do |c, acc|
        acc[(c[:stock_id] || c['stock_id']).to_i] = (c[:contado] || c['contado'])
      end
    end

    # Se cuenta TODO lo que está sobre la mesa. Dejar contar sólo algunos sería un arqueo que no
    # arquea: el que falta se arrastra al turno siguiente como si nada hubiera pasado.
    def validar_conteos
      sin_contar = sobre_la_mesa.reject do |mi|
        v = contado_por_stock[mi.stock_id]
        v.present? || v == 0 || v.to_s == '0'
      end
      return nil if sin_contar.empty?

      "Falta contar: #{sin_contar.map { |mi| mi.stock&.etiqueta }.compact.join(', ')}"
    end

    # Acá la diferencia SÍ ajusta el inventario real: el producto estaba sobre la mesa, se contó,
    # y no está. Va como `ajuste` con motivo, NUNCA como `merma`: el informe de Pérdidas cuenta
    # merma —producto destruido— y anotarlo ahí declararía destruido algo que puede estar entero.
    def aplicar_conteos!
      sobre_la_mesa.each do |mi|
        esperado = mi.cantidad.to_d
        contado  = contado_por_stock[mi.stock_id].to_d
        raise ArgumentError, 'La cantidad contada no puede ser negativa' if contado.negative?

        dif = contado - esperado

        item = @turno.items.find_or_initialize_by(stock_id: mi.stock_id)
        item.club_id           ||= @turno.club_id
        item.cantidad_apertura ||= 0
        item.esperado_cierre     = esperado
        item.cantidad_cierre     = contado
        item.motivo_diferencia   = motivo_diferencia(dif) if dif != 0
        item.save!

        next if dif.zero?
        # LO CONTADO QUEDA ESCRITO IGUAL, pero un sobrante de quien atiende no toca el inventario.
        next if sobrante_sin_aplicar?(dif)

        mi.mover!(cantidad: dif, tipo: 'ajuste', usuario: @usuario, turno: @turno,
                  motivo: motivo_del_ajuste(dif))
        mi.ajustar_inventario!(dif, usuario: @usuario, turno: @turno,
                               concepto: 'Arqueo del mostrador', notas: @notas)
      end
    end

    # CONTAR NO PUEDE CREAR PRODUCTO DE LA NADA — no para quien atiende.
    #
    # `ajustar_inventario!` con una diferencia positiva SUMA al stock del club: contando 997 donde
    # había 100 entraban 897 g trazables que nadie cargó. Es una puerta de entrada de producto sin
    # origen, y se dispara con un dedazo.
    #
    # Quien atiende no puede justificar un sobrante: él no elige qué hay sobre la mesa, la carga
    # administración. Si de verdad sobra, lo carga ella por su puerta, que descuenta del depósito
    # y deja su motivo.
    #
    # PERO EL CIERRE NO SE BLOQUEA: a las once de la noche nadie puede quedar trabado esperando a
    # un admin. Se guarda lo que contó —el dato no se pierde— sin mover el inventario, y el turno
    # cae en la lista de revisión como `sobrante`. El faltante sí se aplica como siempre: restar
    # lo que no está no inventa nada.
    def sobrante_sin_aplicar?(dif) = dif.positive? && @usuario&.atiende_mostrador?

    def motivo_diferencia(dif)
      return @notas.presence unless sobrante_sin_aplicar?(dif)

      ["Contó #{dif.abs.round(3)} de más — queda anotado, no se cargó al inventario",
       @notas.presence].compact.join(' — ')
    end

    def motivo_del_ajuste(dif)
      "Conteo de cierre — #{dif.negative? ? 'faltante' : 'sobrante'} de #{dif.abs.round(3)}" \
        "#{@notas.present? ? " — #{@notas}" : ''}"
    end

    # El orden importa: primero se cierra la caja con lo contado (ahí se asienta la diferencia de
    # arqueo contra lo esperado) y RECIÉN DESPUÉS sale el retiro. Al revés, el retiro contaría
    # como una salida del turno, bajaría lo esperado y la diferencia saldría mal para siempre.
    def cerrar_la_caja!
      caja = @turno.caja_turno
      return if caja.nil? || @efectivo.nil? || caja.cerrada?

      caja.cerrar!(cerrada_por: @usuario, efectivo_declarado: @efectivo.to_d, notas: @notas)
      registrar_retiro!(caja)
    end

    # Lo que se saca del cajón al cerrar: la recaudación, que va a la caja fuerte o al banco. Es
    # `retiro_caja` —un `ajuste`, no un egreso— porque esa plata sigue siendo del club. Lo que
    # queda es el fondo, y el que abre mañana lo hereda en vez de declararlo.
    def registrar_retiro!(caja)
      contado = @efectivo.to_d
      fondo   = @fondo.nil? ? contado : @fondo.to_d
      raise ArgumentError, 'El fondo que queda no puede ser mayor a lo contado' if fondo > contado

      retiro = contado - fondo
      return if retiro <= 0

      dueño = @retirado_por || @usuario
      # La recaudación queda a nombre de alguien que responde por ella, y quien atiende no es ese
      # alguien: no se lleva la plata a su casa. Si cierra un dispensador y no hay a quién
      # atribuirle el retiro, lo correcto es dejar todo como fondo —la plata se queda en el
      # cajón, que es donde está— y que lo retire después quien corresponda.
      unless MovimientoContable::ROLES_RETIRO.include?(dueño&.role)
        raise ArgumentError,
              'El retiro tiene que quedar a nombre de un administrador o supervisor. ' \
              'Si no hay ninguno, dejá todo como fondo y que lo retiren después.'
      end

      caja.movimientos_contables.create!(
        club: @turno.club, sede_id: caja.sede_id, created_by: @usuario,
        tipo: 'ajuste', categoria: 'retiro_caja', retirado_por: dueño,
        descripcion: "Retiro de caja — recaudación de la jornada del " \
                     "#{caja.abierta_at&.to_date&.strftime('%d/%m/%Y')} (queda $#{fondo.to_i} de fondo)",
        monto_ars: retiro, fecha: Time.zone.today,
        pagado: true, medio_pago: 'efectivo', comprobante_tipo: 'sin_comprobante'
      )
    end
  end
end
