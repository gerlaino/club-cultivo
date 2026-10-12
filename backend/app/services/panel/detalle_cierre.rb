# EL DETALLE DE UN CIERRE QUE PIDE ATENCIÓN (panel de conducción, 12-oct-2026).
#
# «Faltan $ 12.400» no se puede revisar: hay que ver de dónde sale la cuenta, qué dijo quien
# cerró, qué pudo haberlo causado y qué pasó en la jornada. Todo sale de los mismos lugares que el
# arqueo (`CajaTurno#efectivo_esperado_ars` y sus partes) y que el cierre del mostrador
# (`TurnoMostradorItem#diferencia_cierre`): el detalle no recalcula, desglosa.
module Panel
  class DetalleCierre
    TOLERANCIA_ARS = 1 # una dispensa «del mismo importe» que la diferencia, redondeos aparte

    def initialize(turno)
      @turno = turno
      @caja  = turno.caja_turno
    end

    def call
      {
        turno_id:   @turno.id,
        sede:       { id: @turno.mostrador&.sede_id, nombre: @turno.mostrador&.sede&.nombre },
        responsable: responsable&.nombre_completo,
        abierto_at: @turno.abierto_at,
        cerrado_at: @turno.cerrado_at,
        revisado:   @turno.revisado_at.present?,
        revisado_por: @turno.revisado_por&.nombre_completo,
        observacion: @turno.notas_cierre.presence,
        conciliacion: conciliacion,
        inventario:  inventario,
        causas:      causas,
        jornada:     jornada,
      }
    end

    private

    def responsable = @turno.cerrado_por || @turno.abierto_por
    def diferencia  = @caja&.diferencia_ars.to_d

    def cobros_efectivo
      @cobros_efectivo ||= @caja ? @caja.cobros_del_arqueo.where(medio: 'efectivo').includes(dispensacion: :paciente).to_a : []
    end

    # La cuenta del arqueo, renglón por renglón, en el orden en que la hace quien cuenta.
    def conciliacion
      return nil unless @caja

      lineas = [{ concepto: 'Fondo inicial declarado en la apertura', monto: @caja.monto_inicial_ars.to_f }]
      n = cobros_efectivo.map(&:dispensacion_id).uniq.size
      lineas << { concepto: "Cobros en efectivo (#{n} dispensa#{n == 1 ? '' : 's'})", monto: @caja.total_efectivo_ars.to_f }
      otros = @caja.total_otros_ingresos_efectivo_ars.to_f
      lineas << { concepto: 'Otros ingresos en efectivo (cuentas corrientes, señas)', monto: otros } if otros.nonzero?
      ing = @caja.total_ingresos_ars.to_f
      lineas << { concepto: 'Ingresos a la caja (devoluciones, reposición de fondo)', monto: ing } if ing.nonzero?
      @caja.salidas.order(:created_at).each do |m|
        lineas << { concepto: "#{m.categoria == 'retiro_caja' ? 'Retiro de administración' : 'Salida de caja'} (#{hora(m.created_at)})" +
                              (m.descripcion.present? ? " · #{m.descripcion}" : ''),
                    monto: -m.monto_ars.to_f }
      end
      {
        lineas: lineas,
        esperado: @caja.efectivo_esperado_ars.to_f,
        declarado: @caja.efectivo_declarado_ars&.to_f,
        diferencia: @caja.diferencia_ars&.to_f,
      }
    end

    # Los productos con diferencia al contar, con su costo.
    def inventario
      @turno.items.includes(:stock).select { |it| it.diferencia_cierre.to_d.nonzero? }.map do |it|
        d = it.diferencia_cierre.to_d
        {
          producto: [it.stock&.etiqueta, it.stock&.numero_lote_producto].compact.join(' · '),
          unidad: it.stock&.unidad || 'g',
          esperado: it.esperado_cierre&.to_f, contado: it.cantidad_cierre&.to_f, diferencia: d.to_f,
          costo_ars: (d.abs * it.stock&.costo_unitario_ars.to_d).to_f.round(2),
          motivo: it.motivo_diferencia.presence,
        }
      end.sort_by { |x| x[:diferencia] }
    end

    # LO QUE PUEDE EXPLICAR LA DIFERENCIA. Son pistas con el dato, nunca una conclusión: la
    # decide quien revisa.
    def causas
      out = []
      dif = diferencia
      if dif.nonzero?
        # Faltante: una dispensa cobrada «en efectivo» por el mismo importe pudo haber sido otra
        # forma de pago. Sobrante: una cobrada por otro medio pudo haber entrado en efectivo.
        medio = dif.negative? ? 'efectivo' : Cobro::MEDIOS_PAGADOS - ['efectivo']
        candidatos = @caja.cobros_del_arqueo.where(medio: medio).includes(dispensacion: :paciente).to_a
                          .select { |c| (c.monto_ars.to_d - dif.abs).abs <= TOLERANCIA_ARS }
        candidatos.first(3).each do |c|
          out << {
            tipo: 'mismo_importe', dispensacion_id: c.dispensacion_id,
            texto: "Se registró una dispensa #{dif.negative? ? 'en efectivo' : "por #{c.medio.tr('_', ' ')}"} por " \
                   "#{pesos(c.monto_ars)} a las #{hora(c.created_at)} (paciente #{iniciales(c.dispensacion&.paciente)}), " \
                   'por el mismo importe que la diferencia.',
          }
        end
      end
      if MostradorMovimiento.where(turno_mostrador_id: @turno.id, tipo: %w[carga retiro]).exists?
        out << { tipo: 'mesa_movida', texto: 'Administración modificó el mostrador durante la jornada.' }
      end
      if responsable
        previos = TurnoMostrador.cerrados.where(mostrador_id: @turno.mostrador_id)
                                .where('cerrado_por_id = :u OR (cerrado_por_id IS NULL AND abierto_por_id = :u)', u: responsable.id)
                                .where('cerrado_at < ?', @turno.cerrado_at).includes(:caja_turno).order(cerrado_at: :desc).limit(20).to_a
        limpios = previos.take_while { |t| t.caja_turno.nil? || t.caja_turno.diferencia_ars.to_d.zero? }.size
        if previos.any?
          out << { tipo: 'historial',
                   texto: limpios == previos.size ? "Historial del responsable: #{limpios} cierre#{limpios == 1 ? '' : 's'} anterior#{limpios == 1 ? '' : 'es'} sin diferencias." :
                                                    "Historial del responsable: #{limpios} cierre#{limpios == 1 ? '' : 's'} sin diferencias antes de este." }
        end
      end
      out
    end

    # La jornada en orden: apertura, lo que movió administración, lo que entró y salió de la caja,
    # las dispensas señaladas como posible causa y el cierre.
    def jornada
      ev = [{ at: @turno.abierto_at, texto: "Apertura#{@caja ? " con fondo de #{pesos(@caja.monto_inicial_ars)}" : ''}" }]
      movs = MostradorMovimiento.where(turno_mostrador_id: @turno.id, tipo: %w[carga retiro]).order(:created_at).to_a
      movs.group_by { |m| [m.tipo, m.created_at.in_time_zone.strftime('%H:%M')] }.each do |(tipo, _), ms|
        ev << { at: ms.first.created_at,
                texto: "Administración #{tipo == 'carga' ? 'asignó' : 'retiró'} #{ms.size} producto#{ms.size == 1 ? '' : 's'} #{tipo == 'carga' ? 'al' : 'del'} mostrador" }
      end
      if @caja
        @caja.salidas.each { |m| ev << { at: m.created_at, texto: "#{m.categoria == 'retiro_caja' ? 'Retiro de administración' : 'Salida de caja'} · #{pesos(m.monto_ars)}" } }
        @caja.ingresos.each { |m| ev << { at: m.created_at, texto: "Ingreso a la caja · #{pesos(m.monto_ars)}" } }
      end
      causas.select { |c| c[:tipo] == 'mismo_importe' }.each do |c|
        cobro = Cobro.find_by(dispensacion_id: c[:dispensacion_id])
        ev << { at: cobro&.created_at, texto: c[:texto].sub(/\ASe registró una /, 'Dispensa ').sub(/, por el mismo importe.*\z/, '') } if cobro
      end
      if @turno.cerrado_at
        faltan = @turno.items.count { |it| it.diferencia_cierre.to_d.nonzero? }
        ev << { at: @turno.cerrado_at,
                texto: "Cierre#{@caja&.efectivo_declarado_ars ? " con #{pesos(@caja.efectivo_declarado_ars)} declarados" : ''} · " +
                       (faltan.zero? ? 'inventario de mostrador conforme' : "#{faltan} producto#{faltan == 1 ? '' : 's'} con diferencia") }
      end
      ev.compact.select { |e| e[:at] }.sort_by { |e| e[:at] }.map { |e| { hora: hora(e[:at]), texto: e[:texto] } }
    end

    def hora(t) = t&.in_time_zone&.strftime('%H:%M')
    def pesos(n) = "$ #{ActiveSupport::NumberHelper.number_to_delimited(n.to_f.round, delimiter: '.')}"

    # Iniciales y no el nombre: el detalle lo ve administración, pero no hace falta el dato.
    def iniciales(p)
      return '—' unless p
      [p.nombre, p.apellido].compact.map { |x| "#{x.to_s.strip[0]}." }.join(' ')
    end
  end
end
