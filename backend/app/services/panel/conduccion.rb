# EL PANEL DE CONDUCCIÓN (12-oct-2026, Germán): el inicio del administrador.
#
# Quien conduce una organización no riega ni atiende el mostrador: necesita saber en un minuto
# si algo se salió de lo normal, cuánto hay en juego y quién se tiene que encargar. El inicio
# anterior eran doce bloques del mismo tamaño que respondían «qué hay», no «qué requiere
# atención». Este servicio arma todo el panel en una respuesta.
#
# REGLA: NINGÚN NÚMERO SE CALCULA DOS VECES. Cada cifra sale de la misma cuenta que usa la pantalla
# que la detalla —la flor seca de `Stock.flor_seca_disponible`, las cuentas por cobrar como en
# Contabilidad, las diferencias de un cierre como en Mostrador— y el cruce se prueba en
# `spec/requests/panel_conduccion_spec.rb` (ver `informe_vs_pantalla_spec.rb`).
#
# Filtros: `sede_id` (nil = toda la organización) y `periodo` (hoy | semana | mes), que gobierna
# el resultado, los atendidos y la trazabilidad. Lo que es «ahora» (cajas abiertas, stock,
# alertas) no depende del período.
module Panel
  class Conduccion
    PERIODOS = %w[hoy semana mes].freeze
    DIAS_ALERTA = 30          # cierres sin revisar que todavía piden atención
    DIAS_PROMEDIO = 28        # ventana del promedio de dispensa diaria
    DIAS_REPROCANN = 15       # REPROCANN que vencen pronto

    def initialize(club:, sede_id: nil, periodo: 'mes', hoy: Time.zone.today)
      @club    = club
      @hoy     = hoy
      @periodo = periodo.to_s.presence_in(PERIODOS) || 'mes'
      @sede    = sede_id.present? ? club.sedes.find(sede_id) : nil
    end

    def call
      atencion = atencion_items
      {
        generado_at: Time.current,
        periodo:     @periodo,
        rango:       { desde: rango.first, hasta: rango.last },
        sede:        @sede && { id: @sede.id, nombre: @sede.nombre },
        sedes:       @club.sedes.order(:nombre).map { |s| { id: s.id, nombre: s.nombre } },
        atencion:    atencion,
        seguimiento: seguimiento,
        en_orden:    en_orden,
        finanzas:    finanzas,
        inventario:  inventario,
        pacientes:   pacientes,
        cultivo:     cultivo,
        trazabilidad: trazabilidad,
        estado_sedes: estado_sedes,
        equipo:      equipo,
        serie_mes:   serie_mes,
      }
    end

    private

    # ── Rangos ─────────────────────────────────────────────────────────────

    def rango
      @rango ||= case @periodo
                 when 'hoy'    then @hoy..@hoy
                 when 'semana' then @hoy.beginning_of_week..@hoy
                 else               @hoy.beginning_of_month..@hoy
                 end
    end

    # El mismo tramo, un período atrás: el mes pasado hasta el mismo día, la semana pasada hasta el
    # mismo día de la semana, ayer. Comparar el mes en curso contra un mes entero lo haría siempre
    # «peor» hasta el día 30.
    def rango_anterior
      @rango_anterior ||= case @periodo
                          when 'hoy'    then (@hoy - 1)..(@hoy - 1)
                          when 'semana' then (rango.first - 7)..(@hoy - 7)
                          else
                            desde = (@hoy - 1.month).beginning_of_month
                            desde..[desde + (@hoy.day - 1), desde.end_of_month].min
                          end
    end

    def rango_tiempo(r) = r.first.beginning_of_day..r.last.end_of_day

    def sede_ids
      @sede_ids ||= @sede ? [@sede.id] : @club.sedes.pluck(:id)
    end

    def mostradores
      @mostradores ||= Mostrador.where(club_id: @club.id, sede_id: sede_ids)
    end

    # Las dispensas no tienen `club_id`: son de la organización por su paciente (como Informes).
    def pacientes_ids = Paciente.unscoped.where(club_id: @club.id).select(:id)

    def dispensas(todas: false)
      base = Dispensacion.where(paciente_id: pacientes_ids)
      todas ? base : base.no_canceladas
    end

    # ── Requiere atención ─────────────────────────────────────────────────

    # Ordenado por impacto en pesos: lo que más cuesta, primero.
    def atencion_items
      (cierres_con_diferencia + cajas_sin_cerrar + rendiciones_pendientes).sort_by { |a| -a[:impacto_ars].to_f }
    end

    def cierres_sin_revisar
      @cierres_sin_revisar ||= TurnoMostrador.cerrados
                                             .where(mostrador_id: mostradores.select(:id), revisado_at: nil)
                                             .where('turno_mostradores.cerrado_at >= ?', DIAS_ALERTA.days.ago)
                                             .includes(:cerrado_por, :abierto_por, :caja_turno, mostrador: :sede, items: :stock)
                                             .order(cerrado_at: :desc).to_a
    end

    # Un cierre puede pedir atención por la PLATA (faltó o sobró efectivo) y por el PRODUCTO
    # (faltó mercadería al contar). Son dos asuntos y dos arreglos distintos: van por separado.
    def cierres_con_diferencia
      cierres_sin_revisar.flat_map do |t|
        sede = t.mostrador&.sede&.nombre
        quien = (t.cerrado_por || t.abierto_por)&.nombre_completo
        out = []
        dif = t.caja_turno&.diferencia_ars.to_d
        if dif.nonzero?
          out << {
            tipo: 'caja', id: "caja-#{t.id}", turno_id: t.id, sede_id: t.mostrador&.sede_id,
            severidad: dif.negative? ? 'alta' : 'media',
            titulo: "#{dif.negative? ? 'Faltante' : 'Sobrante'} de caja · #{sede}",
            detalle: "Cierre del #{fecha_corta(t.cerrado_at)}, #{hora(t.cerrado_at)} · Responsable: #{quien} · " \
                     "Esperado #{pesos(t.caja_turno.efectivo_esperado_ars)} · Declarado #{pesos(t.caja_turno.efectivo_declarado_ars)}",
            valor: dif.to_f, unidad: 'ars', impacto_ars: dif.abs.to_f,
            accion: 'Analizar',
          }
        end
        faltan = t.items.select { |it| it.diferencia_cierre.to_d.negative? }
        if faltan.any?
          peor = faltan.max_by { |it| -it.diferencia_cierre.to_d * it.stock&.costo_unitario_ars.to_d }
          ars  = faltan.sum { |it| -it.diferencia_cierre.to_d * it.stock&.costo_unitario_ars.to_d }
          cant = faltan.sum { |it| -it.diferencia_cierre.to_d }
          unidad = faltan.map { |it| it.stock&.unidad || 'g' }.uniq
          out << {
            tipo: 'inventario', id: "inv-#{t.id}", turno_id: t.id, sede_id: t.mostrador&.sede_id,
            severidad: 'media',
            titulo: "Diferencia de inventario · Mostrador #{sede}",
            detalle: "#{peor.stock&.etiqueta} #{peor.stock&.numero_lote_producto} · Esperado #{num(peor.esperado_cierre)} #{peor.stock&.unidad} · " \
                     "Contado #{num(peor.cantidad_cierre)} #{peor.stock&.unidad}" +
                     (faltan.size > 1 ? " · y #{faltan.size - 1} producto#{faltan.size == 2 ? '' : 's'} más" : ''),
            valor: unidad.size == 1 ? cant.to_f.round(2) : nil, unidad: unidad.size == 1 ? unidad.first : nil,
            impacto_ars: ars.to_f.round(2),
            accion: 'Analizar',
          }
        end
        out
      end
    end

    # El efectivo que un repartidor cobró y todavía no rindió (`Cobro.efectivo_en_transito`, el
    # mismo número que la ficha del usuario), y las rendiciones entregadas que nadie recibió.
    def rendiciones_pendientes
      return [] if @sede # el delivery es de la organización, no de una sede

      # Lo que ya se rindió (tiene `rendicion_caja_id`) y espera que lo reciban va abajo, como
      # rendición sin recibir: contarlo acá también lo mostraría dos veces.
      en_mano = en_transito_sin_rendir
                     .group(:created_by_id).pluck(:created_by_id, Arel.sql('SUM(monto_ars)'), Arel.sql('COUNT(*)'), Arel.sql('MIN(created_at)'))
      usuarios = User.where(id: en_mano.map(&:first)).index_by(&:id)
      items = en_mano.filter_map do |uid, monto, cuantos, desde|
        next unless monto.to_d.positive?
        {
          tipo: 'rendicion', id: "rend-#{uid}", usuario_id: uid,
          severidad: desde < 1.day.ago ? 'media' : 'baja',
          titulo: 'Rendición pendiente · Delivery',
          detalle: "Efectivo de #{cuantos} entrega#{cuantos == 1 ? '' : 's'} sin rendir desde el #{fecha_corta(desde)} · " \
                   "Responsable: #{usuarios[uid]&.nombre_completo}",
          valor: monto.to_f.round(2), unidad: 'ars', impacto_ars: monto.to_f.round(2),
          accion: 'Ver rendiciones', ruta: '/delivery/rendiciones',
        }
      end
      RendicionCaja.pendientes.where(club_id: @club.id).includes(:delivery, :receptor).find_each do |r|
        items << {
          tipo: 'rendicion_sin_recibir', id: "rcj-#{r.id}",
          severidad: 'media',
          titulo: 'Rendición entregada sin recibir',
          detalle: "#{r.delivery&.nombre_completo} rindió el #{fecha_corta(r.rendida_at || r.created_at)}" +
                   (r.receptor ? " a #{r.receptor.nombre_completo}" : '') + ' · falta que se cuente y se reciba',
          valor: r.monto_declarado_ars.to_f, unidad: 'ars', impacto_ars: r.monto_declarado_ars.to_f,
          accion: 'Ver rendiciones', ruta: '/delivery/rendiciones',
        }
      end
      items
    end

    def en_transito_sin_rendir = Cobro.efectivo_en_transito.where(club_id: @club.id, rendicion_caja_id: nil)

    # UNA CAJA QUE QUEDÓ ABIERTA DE UN DÍA PARA OTRO. El arqueo diario es el control: una caja que
    # no se cierra acumula días de efectivo sin contar.
    HORAS_CAJA_ABIERTA = 24

    def cajas_sin_cerrar
      CajaTurno.activas.where(club_id: @club.id, sede_id: sede_ids)
               .where('abierta_at < ?', HORAS_CAJA_ABIERTA.hours.ago).includes(:sede, :abierta_por).map do |c|
        dias = (@hoy - c.abierta_at.in_time_zone.to_date).to_i
        esperado = c.efectivo_esperado_ars.to_d
        {
          tipo: 'caja_abierta', id: "abierta-#{c.id}", sede_id: c.sede_id,
          severidad: dias > 2 ? 'alta' : 'media',
          titulo: "Caja abierta sin cerrar · #{c.sede&.nombre}",
          detalle: "Abierta el #{fecha_corta(c.abierta_at)} a las #{hora(c.abierta_at)} (hace #{dias} día#{dias == 1 ? '' : 's'}) · " \
                   "Responsable: #{c.abierta_por&.nombre_completo} · Efectivo esperado #{pesos(esperado)}",
          valor: dias, unidad: 'dias', impacto_ars: esperado.to_f,
          accion: 'Ir al mostrador', ruta: '/mostrador',
        }
      end
    end

    # Lo que no es urgente pero hay que seguir: se cuenta y se enlaza.
    def seguimiento
      activos = pacientes_activos
      [
        ['reprocann', activos.where(reprocann_vencimiento: @hoy..(@hoy + DIAS_REPROCANN)).count,
         ["REPROCANN vence en los próximos #{DIAS_REPROCANN} días", "REPROCANN vencen en los próximos #{DIAS_REPROCANN} días"], '/pacientes'],
        ['pesajes', PesajeManicura.where(club_id: @club.id, estado: 'enviado').count,
         ['pesaje de manicura pendiente de aprobación', 'pesajes de manicura pendientes de aprobación'], '/admin/pesajes-manicura'],
        ['altas', Paciente.for_club(@club.id).pendientes_aprobacion.count,
         ['alta de paciente pendiente de aprobación', 'altas de pacientes pendientes de aprobación'], '/pacientes'],
        ['tareas', Tarea.del_club(@club.id).vencidas.count, ['tarea vencida', 'tareas vencidas'], '/tareas'],
      ].filter_map do |clave, n, (uno, varios), ruta|
        { clave: clave, cantidad: n, texto: n == 1 ? uno : varios, ruta: ruta } if n.positive?
      end
    end

    # LOS CONTROLES QUE SE CUMPLEN, como constancia del monitoreo. Un control que no se cumple no
    # va acá: ya está en «Requiere atención» o en seguimiento.
    def en_orden
      out = []
      ultimos = TurnoMostrador.cerrados.where(mostrador_id: mostradores.select(:id))
                              .where('turno_mostradores.cerrado_at >= ?', 7.days.ago).includes(:caja_turno).to_a
      if ultimos.any?
        sin_dif = ultimos.count { |t| t.caja_turno.nil? || t.caja_turno.diferencia_ars.to_d.zero? }
        out << { clave: 'cierres', titulo: 'Cierres de caja',
                 texto: "#{sin_dif} de #{ultimos.size} sin diferencias en los últimos 7 días" } if sin_dif * 10 >= ultimos.size * 8
      end
      if !@sede && en_transito_sin_rendir.none? && RendicionCaja.pendientes.where(club_id: @club.id).none?
        out << { clave: 'rendiciones', titulo: 'Rendiciones al día', texto: 'Sin efectivo de delivery pendiente de rendir' }
      end
      c = cultivo
      if c[:capacidad_floracion] && c[:en_floracion] <= c[:capacidad_floracion]
        out << { clave: 'floracion', titulo: 'Plantas en floración',
                 texto: "#{c[:en_floracion]} de #{c[:capacidad_floracion]} habilitadas por el plan" }
      end
      p = pacientes
      if p[:reprocann_vigente_pct] && p[:reprocann_vigente_pct] >= 90
        out << { clave: 'reprocann', titulo: 'REPROCANN vigente', texto: "#{p[:reprocann_vigente_pct]} % de los pacientes activos" }
      end
      out << { clave: 'tareas', titulo: 'Tareas al día', texto: 'Sin tareas vencidas' } if Tarea.del_club(@club.id).vencidas.none?
      out
    end

    # ── Finanzas ────────────────────────────────────────────────────────────

    # Resultado = ingresos − egresos del libro contable (como Contabilidad), en el período y
    # contra el mismo tramo del período anterior.
    def finanzas
      @finanzas ||= begin
        libro = @club.movimientos_contables
        libro = libro.por_sede(@sede.id) if @sede
        actual   = resultado(libro.del_periodo(rango.first, rango.last))
        anterior = resultado(libro.del_periodo(rango_anterior.first, rango_anterior.last))
        cajas = CajaTurno.activas.where(club_id: @club.id, sede_id: sede_ids).to_a
        deudas = CuentaCorriente.where(club_id: @club.id).where('saldo_disponible < 0')
        {
          resultado_ars: actual[:resultado],
          ingresos_ars:  actual[:ingresos],
          egresos_ars:   actual[:egresos],
          resultado_anterior_ars: anterior[:resultado],
          variacion_pct: variacion(actual[:resultado], anterior[:resultado]),
          efectivo_en_cajas_ars: cajas.sum { |c| c.efectivo_esperado_ars.to_d }.to_f.round(2),
          cajas_abiertas: cajas.size,
          # Igual que Contabilidad (`por_cobrar`): la deuda real son los saldos negativos.
          cuentas_por_cobrar_ars: deudas.sum('-saldo_disponible').to_f,
          cuentas_por_cobrar: deudas.count,
        }
      end
    end

    def resultado(scope)
      ing = scope.ingresos.sum(:monto_ars).to_d
      egr = scope.egresos.sum(:monto_ars).to_d
      { ingresos: ing.to_f, egresos: egr.to_f, resultado: (ing - egr).to_f }
    end

    # Ingresos y egresos por día del mes en curso, y los ingresos del mes anterior por número de día.
    def serie_mes
      libro = @club.movimientos_contables
      libro = libro.por_sede(@sede.id) if @sede
      desde = @hoy.beginning_of_month
      ant   = (@hoy - 1.month).beginning_of_month
      ing   = libro.del_periodo(desde, @hoy).ingresos.group(:fecha).sum(:monto_ars)
      egr   = libro.del_periodo(desde, @hoy).egresos.group(:fecha).sum(:monto_ars)
      ing_a = libro.del_periodo(ant, ant.end_of_month).ingresos.group(:fecha).sum(:monto_ars)
      (desde..@hoy).map do |d|
        previo = ant + (d.day - 1)
        { dia: d.day, ingresos: ing[d].to_f, egresos: egr[d].to_f,
          ingresos_mes_anterior: previo.month == ant.month ? ing_a[previo].to_f : nil }
      end
    end

    # ── Inventario ──────────────────────────────────────────────────────────

    def inventario
      stocks = Stock.where(club_id: @club.id)
      stocks = stocks.where(sede_id: @sede.id) if @sede
      disponible = Stock.flor_seca_disponible(stocks).to_f
      diario = dispensado_flor(rango_tiempo((@hoy - (DIAS_PROMEDIO - 1))..@hoy)).to_f / DIAS_PROMEDIO
      {
        flor_seca_disponible_g: disponible.round(1),
        dispensa_promedio_diaria_g: diario.round(1),
        # nil = no hubo dispensas en la ventana: no hay ritmo contra el que medir.
        cobertura_dias: diario.positive? ? (disponible / diario).floor : nil,
        vencimientos_30d: stocks.en_inventario.where(fecha_vencimiento_est: ..(@hoy + 30)).count,
      }
    end

    # Gramos de flor seca dispensados (por línea), sin las anuladas.
    def dispensado_flor(tiempo)
      items = DispensacionItem.joins(:dispensacion, :stock)
                              .merge(Dispensacion.no_canceladas)
                              .where(dispensaciones: { paciente_id: pacientes_ids, fecha_dispensacion: tiempo.first.to_date..tiempo.last.to_date })
                              .where(stocks: { forma_producto: 'flor_seca' })
      items = items.where(dispensaciones: { sede_id: @sede.id }) if @sede
      items.sum('dispensacion_items.cantidad').to_d
    end

    # ── Pacientes ───────────────────────────────────────────────────────────

    def pacientes_activos = Paciente.for_club(@club.id).aprobados

    def pacientes
      @pacientes ||= begin
        activos = pacientes_activos
        cats = activos.pluck(:reprocann_estado, :reprocann_numero, :reprocann_vencimiento).map do |e, n, v|
          Paciente.reprocann_categoria(estado: e, numero: n, vencimiento: v, hoy: @hoy)
        end
        total = cats.size
        disps = dispensas.where(fecha_dispensacion: rango)
        disps = disps.where(sede_id: @sede.id) if @sede
        semana = @hoy.beginning_of_week.beginning_of_day..@hoy.end_of_week.end_of_day
        {
          activos: total,
          atendidos: disps.distinct.count(:paciente_id),
          reprocann_vigente_pct: total.zero? ? nil : (cats.count { |c| %w[vigente por_vencer].include?(c) } * 100.0 / total).round,
          turnos_semana: Turno.where(club_id: @club.id, fecha_hora: semana).where.not(estado: 'cancelado').count,
        }
      end
    end

    # ── Cultivo ─────────────────────────────────────────────────────────────

    def cultivo
      @cultivo ||= begin
        plan = PlanEnforcer.new(@club)
        lotes = Lote.where(club_id: @club.id, estado: %w[vegetativo floracion]).includes(:genetica, :sala)
        lotes = lotes.joins(:sala).where(salas: { sede_id: @sede.id }) if @sede
        proxima = lotes.filter_map { |l| (p = l.proximo_paso) && p[:fase] == 'cosecha' ? [l, p] : nil }
                       .min_by { |_, p| p[:faltan_dias] }
        {
          en_floracion: plan.plantas_en_cupo,
          capacidad_floracion: plan.limite(:plantas),
          proxima_cosecha: proxima && {
            lote_id: proxima[0].id, codigo: proxima[0].codigo, genetica: proxima[0].genetica&.nombre,
            faltan_dias: proxima[1][:faltan_dias], fecha: proxima[1][:fecha],
            rendimiento_estimado_g: proxima[0].rendimiento_objetivo_g&.to_f,
          },
          tareas_vencidas: Tarea.del_club(@club.id).vencidas.count,
        }
      end
    end

    # ── Trazabilidad del producto ────────────────────────────────────────────

    # Del cultivo a la dispensa, en flor seca y en el período. Cada etapa sale de su propio
    # registro: no se deduce una de otra, así una pérdida se ve como diferencia entre dos etapas.
    def trazabilidad
      tiempo = rango_tiempo(rango)
      pesadas = Pesada.joins(:lote).where(lotes: { club_id: @club.id }, registrado_at: tiempo, rechazada_at: nil)
      pesadas = pesadas.joins(lote: :sala).where(salas: { sede_id: @sede.id }) if @sede
      ingreso = Stock.where(club_id: @club.id, forma_producto: 'flor_seca', origen: %w[lote derivado_lote], created_at: tiempo)
      ingreso = ingreso.where(sede_id: @sede.id) if @sede
      a_mostrador = MostradorMovimiento.joins(mostrador_item: [:stock, :mostrador])
                                       .where(club_id: @club.id, tipo: 'carga', created_at: tiempo)
                                       .where(mostradores: { sede_id: sede_ids }, stocks: { forma_producto: 'flor_seca' })
      contados = TurnoMostradorItem.joins(:stock, turno_mostrador: :mostrador)
                                   .where(turno_mostradores: { cerrado_at: tiempo }, mostradores: { sede_id: sede_ids })
                                   .where(stocks: { forma_producto: 'flor_seca' })
                                   .where.not(cantidad_cierre: nil).where.not(esperado_cierre: nil)
                                   .where('turno_mostrador_items.cantidad_cierre < turno_mostrador_items.esperado_cierre')
      dispensado = dispensado_flor(tiempo)
      {
        cosecha_g:     pesadas.sum(:peso_seco_g).to_f.round(1),
        ingreso_stock_g: ingreso.sum(:cantidad_inicial).to_f.round(1),
        a_mostrador_g: a_mostrador.sum('mostrador_movimientos.cantidad').to_f.round(1),
        dispensado_g:  dispensado.to_f.round(1),
        pacientes:     pacientes[:atendidos],
        diferencias_g: contados.sum('turno_mostrador_items.esperado_cierre - turno_mostrador_items.cantidad_cierre').to_f.round(1),
      }
    end

    # ── Estado de las sedes ─────────────────────────────────────────────────

    def estado_sedes
      sedes = @sede ? [@sede] : @club.sedes.order(:nombre).to_a
      hoy_disps = dispensas.where(fecha_dispensacion: @hoy)
      plata_hoy = hoy_disps.group(:sede_id).sum(:aporte_socio_ars)
      flor_hoy  = DispensacionItem.joins(:dispensacion, :stock).merge(Dispensacion.no_canceladas)
                                  .where(dispensaciones: { paciente_id: pacientes_ids, fecha_dispensacion: @hoy })
                                  .where(stocks: { forma_producto: 'flor_seca' })
                                  .group('dispensaciones.sede_id').sum('dispensacion_items.cantidad')
      sedes.map do |s|
        caja = CajaTurno.activas.de_mostradores.where(club_id: @club.id, sede_id: s.id).order(abierta_at: :desc).first
        mostr = Mostrador.where(club_id: @club.id, sede_id: s.id)
        ultimo = TurnoMostrador.cerrados.where(mostrador_id: mostr.select(:id)).includes(:caja_turno).order(cerrado_at: :desc).first
        en_mesa = MostradorItem.joins(:stock).where(mostrador_id: mostr.select(:id), stocks: { forma_producto: 'flor_seca' }).sum(:cantidad)
        {
          id: s.id, nombre: s.nombre,
          caja: caja && { abierta_at: caja.abierta_at, responsable: caja.abierta_por&.nombre_completo },
          dispensado_hoy_ars: plata_hoy[s.id].to_f, dispensado_hoy_g: flor_hoy[s.id].to_f.round(1),
          en_mostrador_g: en_mesa.to_f.round(1),
          ultimo_cierre: ultimo && { fecha: ultimo.cerrado_at, diferencia_ars: ultimo.caja_turno&.diferencia_ars&.to_f },
        }
      end
    end

    # ── Actividad del equipo, hoy ───────────────────────────────────────────

    # Una línea por persona que HIZO algo hoy o tiene algo atrasado. Sin pacientes. Es de toda la
    # organización: una persona puede trabajar en varias sedes el mismo día.
    def equipo
      dia = @hoy.beginning_of_day..@hoy.end_of_day
      disp = dispensas.where(fecha_dispensacion: @hoy).group(:user_id).count
      entregas = dispensas(todas: true).where(estado_envio: 'entregado', updated_at: dia).group(:delivery_id).count
      en_mano = en_transito_sin_rendir.group(:created_by_id).sum(:monto_ars)
      hechas = Tarea.del_club(@club.id).completadas.where(fecha_completada: dia).group(:asignada_a_id).count
      vencidas = Tarea.del_club(@club.id).vencidas.group(:asignada_a_id).count
      turnos = Turno.where(club_id: @club.id, fecha_hora: dia).where.not(estado: 'cancelado').group(:medico_id).count
      sin_ver = Turno.where(club_id: @club.id, visto_at: nil).where('fecha_hora >= ?', Time.current).where.not(estado: 'cancelado').group(:medico_id).count
      cajas = CajaTurno.activas.where(club_id: @club.id).pluck(:abierta_por_id, :abierta_at).to_h

      ids = (disp.keys + entregas.keys + en_mano.keys + hechas.keys + vencidas.keys + turnos.keys + sin_ver.keys + cajas.keys).compact.uniq
      User.where(id: ids, club_id: @club.id).del_equipo.map do |u|
        partes = []
        partes << "#{disp[u.id]} dispensa#{disp[u.id] == 1 ? '' : 's'}" if disp[u.id].to_i.positive?
        partes << "caja abierta desde #{cajas[u.id].in_time_zone.to_date == @hoy ? "las #{hora(cajas[u.id])}" : "el #{fecha_corta(cajas[u.id])}"}" if cajas[u.id]
        partes << "#{entregas[u.id]} entrega#{entregas[u.id] == 1 ? '' : 's'}" if entregas[u.id].to_i.positive?
        partes << "#{hechas[u.id]} tarea#{hechas[u.id] == 1 ? '' : 's'} completada#{hechas[u.id] == 1 ? '' : 's'}" if hechas[u.id].to_i.positive?
        partes << "#{turnos[u.id]} turno#{turnos[u.id] == 1 ? '' : 's'}" if turnos[u.id].to_i.positive?
        alertas = []
        alertas << "rendición pendiente de #{pesos(en_mano[u.id])}" if en_mano[u.id].to_d.positive?
        alertas << "#{vencidas[u.id]} tarea#{vencidas[u.id] == 1 ? '' : 's'} vencida#{vencidas[u.id] == 1 ? '' : 's'}" if vencidas[u.id].to_i.positive?
        alertas << "#{sin_ver[u.id]} asignaci#{sin_ver[u.id] == 1 ? 'ón' : 'ones'} sin confirmar" if sin_ver[u.id].to_i.positive?
        { id: u.id, nombre: u.nombre_completo, rol: u.role, actividad: partes, alertas: alertas }
      end.sort_by { |x| [x[:alertas].empty? ? 1 : 0, x[:nombre].to_s] }
    end

    # ── Formato ─────────────────────────────────────────────────────────────

    def variacion(actual, anterior)
      return nil if anterior.to_f.zero?
      ((actual.to_f - anterior.to_f) / anterior.to_f.abs * 100).round
    end

    def fecha_corta(t) = t && t.in_time_zone.strftime('%d/%m')
    def hora(t) = t && t.in_time_zone.strftime('%H:%M')
    def num(n) = ActiveSupport::NumberHelper.number_to_delimited(n.to_f.round(2).to_s.sub(/\.0\z/, ''), delimiter: '.', separator: ',')
    def pesos(n) = "$ #{ActiveSupport::NumberHelper.number_to_delimited(n.to_f.round, delimiter: '.')}"
  end
end
