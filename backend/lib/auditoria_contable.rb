# LA AUDITORÍA CONTABLE, como objeto.
#
# Vive en `lib` y no en `app/services` a propósito: es una herramienta de diagnóstico que se corre
# a mano, no algo que use la aplicación. Y es una clase y no código suelto en el rake para poder
# tener tests: una herramienta que grita en falso entrena a ignorar todos los avisos, así que lo
# que hay que verificar no es sólo que encuentre el descuadre, sino que se quede CALLADA con los
# casos legítimos — la dispensa mixta con dos asientos, el efectivo que el repartidor no rindió.
class AuditoriaContable
  def initialize(club, detalle: false)
    @club    = club
    @detalle = detalle
    @total   = 0
  end

  def call
    cuentas_corrientes_despegadas
    dispensas_con_asientos_que_no_cuadran
    cobros_huerfanos
    cajas_con_cobros_anulados_despues_del_cierre
    @total
  end

  private

  def seccion(titulo, casos, explicacion)
    if casos.empty?
      puts "  ✓ #{titulo}"
      return
    end

    @total += casos.size
    puts "  ✗ #{titulo}: #{casos.size}"
    puts "     #{explicacion}"
    lista = @detalle ? casos : casos.first(5)
    lista.each { |c| puts "     · #{c}" }
    puts "     … y #{casos.size - lista.size} más (DETALLE=1 para verlos todos)" if casos.size > lista.size
  end

  # EL SALDO CONTRA SU PROPIO HISTORIAL.
  #
  # Cada movimiento guarda `saldo_nuevo`, así que el saldo de la cuenta tiene que ser igual al
  # del último movimiento. Si no coincide, o alguien escribió el saldo sin registrar el
  # movimiento, o un movimiento se borró después: en los dos casos el historial que ve el
  # paciente ya no explica lo que dice su cuenta.
  def cuentas_corrientes_despegadas
    casos = []
    CuentaCorriente.where(club_id: @club.id).includes(:paciente).find_each do |cc|
      ultimo = cc.movimientos.where("unidad IS NULL OR unidad = 'ars'").order(:created_at, :id).last
      next if ultimo.nil?

      if (cc.saldo_disponible.to_d - ultimo.saldo_nuevo.to_d).abs > 0.01
        casos << "CC ##{cc.id} (#{cc.paciente&.nombre_completo}): saldo #{cc.saldo_disponible.to_f} " \
                 "pero el último movimiento (##{ultimo.id}) dejó #{ultimo.saldo_nuevo.to_f}"
      end
    end
    seccion('Saldos de cuenta corriente que coinciden con su historial', casos,
            'El saldo dice una cosa y el último movimiento otra: falta un movimiento o sobra una escritura.')
  end

  # LO ASENTADO CONTRA LO COBRADO, en un solo número.
  #
  # No alcanza con "¿tiene asiento?" ni con "¿tiene más de uno?": las dos preguntas sueltas
  # gritan en falso y un aviso que grita en falso entrena a ignorar todos los demás.
  #   · Una dispensa pagada mitad en efectivo y mitad a cuenta corriente lleva DOS asientos, y
  #     está bien.
  #   · El efectivo que cobró el repartidor y todavía no rindió NO tiene asiento a propósito:
  #     esa plata está en su bolsillo hasta que la entrega (`Cobro#rendido`).
  #
  # Lo que sí tiene que cerrar es el total: lo asentado = lo cobrado − lo que sigue en la calle.
  # Así, un asiento de más (el ingreso del mes inflado) y uno de menos (una venta que no figura)
  # salen los dos por el mismo lado.
  def dispensas_con_asientos_que_no_cuadran
    casos = []
    # `IS DISTINCT FROM` y no `where.not`: una dispensa SIN envío tiene `estado_envio` en NULL, y
    # en SQL `estado_envio != 'cancelada'` es NULL para esas filas — o sea, no matchea ninguna.
    # Con `where.not`, la auditoría miraba únicamente las dispensas con reparto (las menos) y
    # contestaba "todo bien" sin haber revisado casi nada. Lo encontraron los tests: el rake
    # sobre datos reales daba verde igual.
    Dispensacion.joins(:paciente).where(pacientes: { club_id: @club.id })
                .where("dispensaciones.estado_envio IS DISTINCT FROM 'cancelada'")
                .where('aporte_socio_ars > 0')
                .includes(:movimientos_contables, :cobros, :paciente)
                .find_each do |d|
      # LO QUE EL CLUB YA TIENE COBRADO, que es lo único que corresponde asentar. Hay dos
      # excepciones legítimas, y son las únicas que el código declara:
      #   · el efectivo que cobró el repartidor y todavía no rindió — está en su bolsillo
      #     (`Cobro#rendido`) y su asiento se hace al recibir la caja;
      #   · una contra-entrega que todavía no cobró nada: ahí no entró un peso.
      #
      # Todo el resto del aporte tiene que estar asentado, se haya pagado en efectivo, a cuenta
      # corriente o partido entre los dos. Se compara el TOTAL y no cuántas filas hay: una
      # dispensa mixta lleva dos asientos y está perfecta.
      en_la_calle = d.cobros.select { |c| c.medio == 'efectivo' && c.contexto == 'entrega' && !c.rendido }
                     .sum { |c| c.monto_ars.to_d }
      esperado =
        if d.cobrar_en_entrega? && d.cobros.empty?
          0.to_d
        else
          d.aporte_socio_ars.to_d - en_la_calle
        end
      asentado = d.movimientos_contables.sum { |m| m.monto_ars.to_d }
      next if (asentado - esperado).abs <= 1

      detalle = if asentado > esperado
                  "asentó #{asentado.to_f} de más sobre #{esperado.to_f}"
                else
                  "asentó #{asentado.to_f} de #{esperado.to_f}"
                end
      casos << "Dispensa ##{d.id} del #{d.fecha_dispensacion} (#{d.paciente&.nombre_completo}): #{detalle}" \
               "#{" — $#{en_la_calle.to_f} sin rendir todavía" if en_la_calle.positive?}"
    end
    seccion('Dispensas cuyo asiento coincide con lo cobrado', casos,
            'De más infla el ingreso del mes; de menos es plata que entró y no figura. Ninguna de las dos se ve sola.')
  end

  # Un cobro vivo colgando de una dispensa cancelada es plata contada dos veces: la dispensa se
  # revirtió pero su cobro sigue sumando al arqueo del turno.
  def cobros_huerfanos
    casos = []
    Cobro.where(club_id: @club.id).includes(:dispensacion).find_each do |c|
      d = c.dispensacion
      next if d.present? && d.estado_envio != 'cancelada'

      casos << "Cobro ##{c.id} de $#{c.monto_ars.to_f} (#{c.medio}) sobre una dispensa " \
               "#{d.nil? ? 'que ya no existe' : 'cancelada'}"
    end
    seccion('Cobros atados a una dispensa viva', casos,
            'Ese cobro sigue sumando al arqueo de su turno aunque la dispensa se haya revertido.')
  end

  # INFORMATIVO, no es un error: las cajas donde se canceló algo DESPUÉS de cerrarlas. Hasta el
  # arreglo de `cobros_del_arqueo`, cada una de éstas mostraba un sobrante que nadie podía
  # explicar — el turno cerraba cuadrado y al día siguiente aparecía descuadrado solo.
  def cajas_con_cobros_anulados_despues_del_cierre
    casos = []
    CajaTurno.where(club_id: @club.id, estado: 'cerrada').where.not(cerrada_at: nil).find_each do |caja|
      anulados = caja.cobros.only_deleted.where('cobros.deleted_at >= ?', caja.cerrada_at)
      next if anulados.empty?

      casos << "Caja ##{caja.id} cerrada el #{caja.cerrada_at.to_date}: " \
               "#{anulados.count} cobro(s) anulados después, por $#{anulados.sum(:monto_ars).to_f}"
    end
    seccion('Arqueos cerrados sin movimientos posteriores', casos,
            'Informativo: su arqueo se veía movido hasta el arreglo; ahora se calcula congelado.')
  end
end
