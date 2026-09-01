module Mostradores
  # Cerrar el mostrador: los dos arqueos, en un solo gesto.
  #
  # La merma es INEVITABLE y no es culpa de nadie: se cuenta para que la organización sepa cuánta
  # hay y dónde, y con eso encuentre sus cuellos de botella. Nada de esto está para señalar a
  # alguien, y el texto que ve el usuario tiene que sonar así.
  #
  # CIERRA EN EL ACTO, sin esperar al admin. Si el turno quedara pendiente de su visto bueno, a
  # las once de la noche el mostrador está bloqueado y el que abre mañana no puede arrancar. El
  # aval del admin es asincrónico: la diferencia queda en su bandeja y la mira cuando aparece.
  #
  # Los dos arqueos son INDEPENDIENTES y sólo el efectivo los cruza:
  #   • mercadería → se cuenta todo lo que está sobre la mesa, sin mirar el medio de pago. Una
  #     dispensa a cuenta corriente sacó el producto igual, y una con envío también.
  #   • plata      → sólo lo que entró al cajón. La cuenta corriente es deuda registrada, y el
  #     efectivo que cobró el repartidor está en su bolsillo hasta que rinde.
  #
  # Y el agujero que cerramos acá: hasta hoy el cierre pedía el efectivo contado y nada más. Si
  # contabas $230.000 y mañana abrías con $50.000 de fondo, los otros $180.000 no tenían ningún
  # movimiento que dijera que salieron del cajón. Ahora el cierre parte lo contado en el fondo
  # que queda y el RETIRO de la recaudación, que sale con nombre y apellido.
  class CerrarTurno
    Result = Struct.new(:ok, :turno, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    # `conteos`: [{ item_id:, contado:, motivo: }] — uno por ítem, TODOS.
    def initialize(turno:, usuario:, conteos: [], efectivo_contado_ars: nil,
                   fondo_siguiente_ars: nil, retirado_por: nil, notas: nil)
      @turno    = turno
      @usuario  = usuario
      @conteos  = Array(conteos).select { |c| c.respond_to?(:[]) && !c.is_a?(String) }
      @efectivo = efectivo_contado_ars
      @fondo    = fondo_siguiente_ars
      @retirado_por = retirado_por || usuario
      @notas    = notas
    end

    def call
      return err('El mostrador no está abierto') unless @turno&.abierto?

      faltan = validar_conteos
      return err(faltan) if faltan

      ActiveRecord::Base.transaction do
        aplicar_conteos!
        @turno.update!(estado: 'cerrado', cerrado_por: @usuario, cerrado_at: Time.current,
                       notas_cierre: @notas.presence)
        cerrar_caja!
      end
      Result.new(ok: true, turno: @turno.reload)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    def por_item = @por_item ||= @conteos.index_by { |c| (c[:item_id] || c['item_id']).to_i }

    # Se cuenta TODO lo que está sobre la mesa. Dejar contar sólo algunos ítems sería un arqueo
    # que no arquea: el que falta se arrastra al turno siguiente como si nada hubiera pasado.
    def validar_conteos
      sin_contar = @turno.items.en_la_mesa.reject { |it| por_item[it.id] }
      return nil if sin_contar.empty?

      "Falta contar: #{sin_contar.map { |it| it.stock&.etiqueta }.compact.join(', ')}"
    end

    def aplicar_conteos!
      @turno.items.en_la_mesa.each do |item|
        datos   = por_item[item.id]
        contado = (datos[:contado] || datos['contado']).to_d
        raise ArgumentError, "La cantidad contada no puede ser negativa" if contado.negative?

        motivo = (datos[:motivo] || datos['motivo']).presence
        if contado != item.esperado && motivo.blank?
          raise ArgumentError,
                "#{item.stock&.etiqueta}: hay diferencia, escribí el motivo"
        end

        item.registrar_cierre!(contado: contado, motivo: motivo, usuario: @usuario)
      end
    end

    # El orden importa: primero se cierra la caja con lo contado (ahí se asienta la diferencia de
    # arqueo contra lo esperado) y RECIÉN DESPUÉS sale el retiro. Al revés, el retiro contaría
    # como una salida del turno, bajaría el esperado y la diferencia de arqueo saldría mal.
    def cerrar_caja!
      caja = @turno.caja_turno
      return if caja.nil? || @efectivo.nil? || caja.cerrada?

      caja.cerrar!(cerrada_por: @usuario, efectivo_declarado: @efectivo.to_d, notas: @notas)
      registrar_retiro!(caja)
    end

    # Lo que se saca del cajón al cerrar: la recaudación del día, que va a la caja fuerte o al
    # banco. Es `retiro_caja` —un `ajuste`, no un egreso— porque esa plata sigue siendo del club:
    # asentarla como gasto inflaría los egresos por plata que nadie gastó. Lo que queda es el
    # fondo, y mañana el que abre lo HEREDA en vez de declararlo.
    def registrar_retiro!(caja)
      contado = @efectivo.to_d
      fondo   = @fondo.nil? ? contado : @fondo.to_d
      raise ArgumentError, 'El fondo que queda no puede ser mayor a lo contado' if fondo > contado

      retiro = contado - fondo
      return if retiro <= 0

      # La recaudación queda a nombre de alguien que responde por ella, y el que atiende el
      # mostrador no es ese alguien: no se lleva la plata a su casa. Si cierra un dispensador y
      # no hay a quién atribuirle el retiro, lo correcto es dejar TODO como fondo —la plata se
      # queda en el cajón, que es donde está de verdad— y que el retiro lo haga después quien
      # corresponda. Inventarle un dueño al retiro sería peor que no registrarlo.
      unless MovimientoContable::ROLES_RETIRO.include?(@retirado_por&.role)
        raise ArgumentError,
              'El retiro tiene que quedar a nombre de un administrador o supervisor. ' \
              'Si no hay ninguno, dejá todo como fondo y que lo retiren después.'
      end

      caja.movimientos_contables.create!(
        club: @turno.club, sede_id: caja.sede_id, created_by: @usuario,
        tipo: 'ajuste', categoria: 'retiro_caja', retirado_por: @retirado_por,
        descripcion: "Retiro de caja — recaudación del turno del " \
                     "#{caja.abierta_at&.to_date&.strftime('%d/%m/%Y')} (queda $#{fondo.to_i} de fondo)",
        monto_ars: retiro, fecha: Time.zone.today,
        pagado: true, medio_pago: 'efectivo', comprobante_tipo: 'sin_comprobante'
      )
    end
  end
end
