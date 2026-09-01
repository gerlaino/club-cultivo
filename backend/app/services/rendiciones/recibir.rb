module Rendiciones
  # El receptor CUENTA la plata y la recibe. Acá entra al cajón y acá se asientan los ingresos.
  #
  # LA PLATA NUNCA QUEDA EN EL AIRE. Es efectivo: el que cuenta es el que la tiene en la mano, y
  # ese número es el que entra, siempre. No hay estado "en disputa" —dejaría plata que no está en
  # ningún lado—. Lo que queda pendiente si hubo ajuste es la CONFORMIDAD del repartidor, que es
  # constancia y no candado.
  #
  # SÓLO SE AJUSTA HACIA ABAJO. Si trajo MÁS de lo que el sistema dice que cobró, es que un cobro
  # no se cargó: eso se arregla cargándolo, no tocando el número de la rendición. Un ajuste para
  # arriba taparía el cobro que falta y la dispensa quedaría figurando impaga para siempre.
  class Recibir
    Result = Struct.new(:ok, :rendicion, :error, keyword_init: true) do
      def ok? = ok
    end

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(rendicion:, receptor:, monto_recibido: nil, motivo: nil)
      @rendicion = rendicion
      @receptor  = receptor
      @monto     = monto_recibido
      @motivo    = motivo
    end

    def call
      return err('Esta rendición ya fue recibida') unless @rendicion&.pendiente?
      return err('No podés recibirte tu propia rendición') if @receptor.id == @rendicion.delivery_id

      declarado = @rendicion.monto_declarado_ars.to_d
      recibido  = @monto.nil? || @monto.to_s.strip.empty? ? declarado : @monto.to_d
      return err('El monto no puede ser negativo') if recibido.negative?

      if recibido > declarado
        return err("Trajo más de lo que figura cobrado ($#{declarado.to_i}). Si falta cargar un " \
                   'cobro, cargalo en su dispensa: ajustar acá lo dejaría figurando impago.')
      end

      diferencia = recibido - declarado
      return err('Falta menos plata de la que cobró: escribí el motivo') if diferencia.negative? && @motivo.blank?

      ActiveRecord::Base.transaction do
        caja = caja_de_recepcion
        @rendicion.cobros.each { |c| asentar_y_rendir!(c, caja) }
        asentar_a_cuenta!(diferencia.abs, caja) if diferencia.negative?
        devolver_paquetes!

        @rendicion.update!(
          estado: 'recibida', receptor: @receptor, caja_turno: caja,
          monto_recibido_ars: recibido, motivo_ajuste: @motivo.presence,
          recibida_at: Time.current,
          # nil = coincidió y no hay nada que conformar. false = hubo ajuste y el repartidor
          # todavía no dijo si está de acuerdo. La plata ya entró igual.
          conforme: diferencia.zero? ? nil : false
        )
      end
      Result.new(ok: true, rendicion: @rendicion.reload)
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      err(e.message)
    end

    private

    def err(msg) = Result.new(ok: false, error: msg)

    # El ingreso se asienta COMPLETO aunque haya traído menos: el paciente pagó esa plata y la
    # dispensa se cobró. Lo que falta no es menos venta, es plata que quedó con una persona — y
    # eso va aparte, en su propio movimiento.
    def asentar_y_rendir!(cobro, caja)
      d     = cobro.dispensacion
      quien = @rendicion.delivery.first_name.presence || @rendicion.delivery.email
      MovimientoContable.create!(
        club: @rendicion.club, sede_id: d&.sede_id, dispensacion: d, paciente: d&.paciente,
        created_by: @receptor, tipo: 'recupero_costo', categoria: 'dispensacion',
        descripcion: "Recepción de caja (#{quien}) — Dispensación ##{d&.id}",
        monto_ars: cobro.monto_ars, fecha: d&.fecha_dispensacion || Time.zone.today,
        pagado: true, medio_pago: 'efectivo', comprobante_tipo: 'sin_comprobante'
      )
      cobro.update!(rendido: true, rendido_at: Time.current, caja_turno: caja)
    end

    # Lo que no entregó queda A NOMBRE SUYO, no como pérdida del club: esa plata existe y está con
    # una persona. Es el mismo criterio que `retiro_caja` ("dame $100.000, anotámelos a mí"): va
    # como `ajuste`, así que no infla los gastos ni baja el resultado por plata que nadie gastó.
    #
    # La categoría es propia y no `retiro_caja` porque ahí sólo puede figurar un admin o
    # supervisor —quien puede sacar del cajón— y acá el que la tiene es el repartidor. El MOTIVO
    # es el que cuenta la historia: "me lo llevo a cuenta de sueldo" y "me faltaron y no sé" son
    # hechos distintos y no los decide la etiqueta.
    def asentar_a_cuenta!(monto, caja)
      MovimientoContable.create!(
        club: @rendicion.club, sede_id: caja&.sede_id, created_by: @receptor,
        caja_turno: caja, tipo: 'ajuste', categoria: 'a_cuenta_repartidor',
        retirado_por: @rendicion.delivery,
        descripcion: "A cuenta de #{@rendicion.delivery.nombre_completo} — #{@motivo}",
        monto_ars: monto, fecha: Time.zone.today,
        pagado: true, medio_pago: 'efectivo', comprobante_tipo: 'sin_comprobante'
      )
    end

    # TODO PAQUETE QUE VUELVE SE DESARMA. No se elige: es una decisión de calidad, no de
    # inventario. Un paquete que estuvo en la calle y volvió no se guarda armado esperando otro
    # intento — cuando se despache de nuevo, se arma en el momento, y para entonces puede haber
    # cambiado hasta la forma de entrega (que lo pase a buscar por la organización, por ejemplo).
    #
    # Así que el producto vuelve al stock y, si hay un mostrador abierto, SUBE A LA MESA por esa
    # cantidad aunque ese frasco no estuviera arriba: si no, el gramo se iba al depósito y el que
    # atiende no lo tenía para el próximo que lo pidiera, con el paquete ahí adelante.
    #
    # Es la misma cancelación de siempre (`Dispensaciones::Cancelar`): revierte stock, cuenta
    # corriente y asientos. Cuando se vuelva a despachar, es una dispensa NUEVA.
    #
    # `reprogramar` sigue existiendo para el reintento del mismo viaje —falla a las 18 y vuelve a
    # intentar a las 19 sin pasar por la base—: ahí el paquete nunca volvió.
    def devolver_paquetes!
      Rendiciones::Rendir.devoluciones_de(@rendicion.delivery, @rendicion.club).each do |d|
        res = Dispensaciones::Cancelar.call(dispensacion: d, usuario: @receptor,
                                            motivo: "Volvió con la rendición ##{@rendicion.id} — " \
                                                    'el paquete se desarma')
        raise ArgumentError, res.error unless res.ok?
      end
    end

    # Dónde entra la plata: en el mostrador del que la recibe.
    def caja_de_recepcion
      sedes = @receptor.sedes_ids_asignadas
      return CajaTurno.abierta_en_sede(club_id: @rendicion.club_id, sede_id: sedes.first) if sedes.one?

      abiertas = CajaTurno.unscoped.where(club_id: @rendicion.club_id, estado: 'abierta')
                          .de_mostradores.limit(2).to_a
      abiertas.one? ? abiertas.first : nil
    end
  end
end
