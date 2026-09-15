class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_analytics_access!, except: [:dispensador]
  before_action :require_dispensador_access!, only: [:dispensador]

  # GET /api/analytics/prendimiento
  # % de prendimiento del enraizado, global y por genética. Es la métrica que hasta ahora se perdía:
  # los esquejes que no agarraban caían en "descartada" mezclados con plagas, machos y roturas.
  #
  # CÓMO SE CUENTA. `intentos` son TODAS las plantas que alguna vez tuvo el lote (las descartadas
  # incluidas: si no, el que no prende desaparece del denominador y el % siempre da 100). De ahí,
  # las que NO prendieron son las que tienen el motivo estructurado; todo el resto prendió —una
  # planta que después se perdió por plaga en floración igual había enraizado bien—.
  #
  # Solo entran lotes con al menos un descarte clasificado o que ya pasaron el enraizado: un lote
  # que está enraizando AHORA todavía no tiene un resultado que medir.
  def prendimiento
    club = current_user.club
    lotes = club.lotes.includes(:genetica)
    lotes = lotes.where('start_date >= ?', Date.parse(params[:desde])) if params[:desde].present?
    lotes = lotes.where('start_date <= ?', Date.parse(params[:hasta])) if params[:hasta].present?

    en_curso = lotes.select { |l| Plant::ESTADOS_ENRAIZANDO.include?(l.estado) }.map(&:id)
    ids      = lotes.map(&:id) - en_curso
    return render json: vacio_prendimiento if ids.empty?

    # Una sola query por métrica, agrupada por lote: nada de N+1.
    totales   = Plant.unscoped.where(lote_id: ids, deleted_at: nil).group(:lote_id).count
    fallados  = Plant.unscoped.where(lote_id: ids, deleted_at: nil, motivo_descarte: 'no_prendio')
                     .group(:lote_id).count

    por_gen = Hash.new { |h, k| h[k] = { intentos: 0, no_prendieron: 0 } }
    lotes.each do |l|
      next unless totales[l.id].to_i.positive?
      k = [l.genetica_id, l.genetica&.nombre || l.strain || 'Sin genética']
      por_gen[k][:intentos]      += totales[l.id].to_i
      por_gen[k][:no_prendieron] += fallados[l.id].to_i
    end

    intentos = por_gen.values.sum { |v| v[:intentos] }
    fallos   = por_gen.values.sum { |v| v[:no_prendieron] }

    render json: {
      global: serializar_prendimiento(intentos, fallos),
      por_genetica: por_gen.map { |(gid, nombre), v|
        serializar_prendimiento(v[:intentos], v[:no_prendieron])
          .merge(genetica_id: gid, genetica: nombre)
      }.sort_by { |g| [-g[:intentos], g[:genetica].to_s] },
    }
  end

  # GET /api/analytics/rendimiento_genetica
  # Para: admin, supervisor, super_admin
  def vacio_prendimiento
    { global: serializar_prendimiento(0, 0), por_genetica: [] }
  end

  def serializar_prendimiento(intentos, fallos)
    prendidas = [intentos - fallos, 0].max
    {
      intentos:      intentos,
      prendidas:     prendidas,
      no_prendieron: fallos,
      # Sin intentos no hay porcentaje: devolver 0 haría leer "0% de prendimiento" donde en realidad
      # no hay dato, que es peor que no mostrar nada.
      porcentaje:    intentos.positive? ? (prendidas * 100.0 / intentos).round(1) : nil,
    }
  end

  # GET /api/analytics/dispensador
  # Para: dispensador, admin
  # El inicio del mostrador. Lo miran el admin y el dispensador, y NO pueden ver lo mismo:
  #
  # El dispensador recibía el tablero completo de la organización — el ranking de consumo del mes
  # con nombre y apellido de cada paciente, cuántos del padrón tienen el REPROCANN vencido, el
  # volumen del club por día. Un ranking de consumo de cannabis con nombre es dato de salud
  # (Ley 25.326) y no es algo que necesite quien atiende el mostrador: para entregar le alcanza
  # con su caja, su stock y sus reservas.
  #
  # Había un comentario en `top_pacientes` justificando el nombre completo con que "quien mira la
  # analítica ya tiene acceso a la ficha del paciente". Es cierto del admin, pero el guard de este
  # endpoint deja entrar también al dispensador, así que el argumento no lo cubría.
  def dispensador
    club = current_user.club
    # ⚠️ La clave incluye al USUARIO. Era sólo por club y por fecha: al personalizar el contenido,
    # el primer dispensador que entrara le serviría SUS datos a todos los demás del club.
    clave = "analytics/dispensador/#{club.id}/#{current_user.id}/#{alcance_dispensador}/#{Time.zone.today}"
    data = Rails.cache.fetch(clave, expires_in: 10.minutes) do
      if alcance_dispensador == 'propio'
        calcular_dispensador_propio(club, current_user)
      else
        calcular_dispensador(club)
      end
    end

    # El estado de la caja va SIEMPRE fresco, fuera del caché.
    #
    # Es lo único de este tablero que cambia por una acción de otra persona y que hay que ver en
    # el momento: el admin abría la caja, volvía al inicio y seguía diciendo "sin abrir" durante
    # diez minutos. Un dato que miente sobre el estado de la plata no puede salir de un caché.
    #
    # El resto sí se cachea: son conteos del día que si llegan con unos minutos de atraso no
    # cambian ninguna decisión.
    render json: data.merge(cajas_por_sede: cajas_por_sede(club))
  end

  # Quién ve todo y quién ve lo suyo. El admin (y el super_admin) siguen viendo la organización
  # entera: es su trabajo. El resto ve su mostrador.
  def alcance_dispensador
    %w[admin super_admin].include?(current_user.role) ? 'club' : 'propio'
  end

  # El tablero acotado: lo que ESTE usuario hizo, y el stock y las reservas de SU sede.
  #
  # No es el mismo payload con menos filas: hay bloques que directamente no van. El estado del
  # REPROCANN del padrón, el volumen del club y las entregas de delivery abiertas son preguntas
  # de quien administra, no de quien entrega.
  # Estado de la caja Y DE LA MESA de cada mostrador, para el tablero del admin.
  #
  # Van juntos a propósito: son el mismo punto de venta y la misma pregunta —"¿está atendiendo?"—.
  # Que la caja tuviera tarjeta y la mercadería no dejaba al admin enterándose por un reclamo de
  # que nadie había abierto el mostrador.
  #
  # `Sede::SUITES_POR_TIPO` ya dice qué sede dispensa: `social` y `mixta`. Una de producción no
  # tiene mostrador y ofrecerle una caja sería ruido — la regla no se reescribe acá.
  def cajas_por_sede(club)
    sedes = club.sedes.activas.where(tipo: %w[social mixta]).order(:nombre).to_a
    return [] if sedes.empty?

    # La caja es del MOSTRADOR y el mostrador es de la sede: hay que dar el rodeo para poder
    # seguir indexando por sede, que es como lo muestra el tablero.
    mostradores = Mostrador.where(club_id: club.id, sede_id: sedes.map(&:id)).index_by(&:id)
    activas = CajaTurno.where(club_id: club.id).del_mostrador(mostradores.keys)
                       .activas.includes(:abierta_por)
                       .index_by { |c| mostradores[c.punto_id]&.sede_id }

    # El turno de mercadería abierto de cada mostrador, con cuántos productos tiene arriba. Una
    # query para todas las sedes, no una por sede.
    turnos = TurnoMostrador.where(club_id: club.id, mostrador_id: mostradores.keys)
                           .abiertos.includes(:abierto_por)
                           .index_by { |t| mostradores[t.mostrador_id]&.sede_id }
    # Cuántos productos hay SOBRE LA MESA. Es del mostrador, no del turno: la mesa existe con la
    # caja abierta y con la caja cerrada, porque el producto está físicamente ahí.
    productos = MostradorItem.where(mostrador_id: mostradores.keys).where('cantidad > 0')
                             .group(:mostrador_id).count

    mostradores_por_sede = mostradores.values.index_by(&:sede_id).transform_values(&:id)

    sedes.map do |sede|
      caja  = activas[sede.id]
      turno = turnos[sede.id]
      {
        sede_id: sede.id,
        sede:    sede.nombre,
        # Tres estados, no dos: "hay mercadería arriba pero nadie abrió la caja" es un momento
        # propio, y es justo donde se traba un arranque — el admin la dejó preparada y el que
        # atiende todavía no llegó.
        mostrador: {
          estado:    estado_del_mostrador(turno, productos[mostradores_por_sede[sede.id]].to_i),
          abierto_por: turno&.abierto_por&.nombre_completo,
          atiende:   turno&.abierto_por&.nombre_completo,
          desde:     turno&.abierto_at,
          productos: productos[mostradores_por_sede[sede.id]].to_i,
        },
        # `sin_abrir` no es un estado de la caja: es la AUSENCIA de caja, y es justo lo que el
        # admin necesita ver de un vistazo.
        estado:  estado_de_la_caja(caja),
        caja_id:                caja&.id,
        abierta_por:            caja&.abierta_por&.nombre_completo,
        abierta_at:             caja&.abierta_at,
        efectivo_esperado_ars:  caja&.efectivo_esperado_ars,
        efectivo_declarado_ars: caja&.efectivo_declarado_ars&.to_f,
        diferencia_ars:         caja&.diferencia_ars,
      }
    end
  end

  # `sin_abrir` = ni mercadería ni caja. `cargado` = la mesa está lista y falta que alguien abra
  # la caja: es el estado donde se traba un arranque y por eso tiene nombre propio.
  def estado_del_mostrador(turno, productos)
    return 'abierto' if turno
    return 'cargado' if productos.positive?

    'sin_abrir'
  end

  # `sin_confirmar` es SOLO del buffet, donde el encargado declara el fondo y quien atiende lo
  # confirma. En el dispensario esa ceremonia no existe — la caja se abre contando, en un solo
  # gesto—, así que preguntarle `apertura_confirmada?` la dejaba `sin_confirmar` para siempre,
  # esperando un paso que ya no le toca a nadie.
  def estado_de_la_caja(caja)
    return 'sin_abrir' if caja.nil?
    return caja.estado if caja.de_dispensario?

    caja.apertura_confirmada? ? caja.estado : 'sin_confirmar'
  end

  def sede_de_mostrador_de(usuario)
    usuario.sede_de_mostrador&.then { |x| { id: x.id, nombre: x.nombre } }
  end

  def calcular_dispensador_propio(club, usuario)
    hoy           = Time.zone.today
    inicio_semana = hoy.beginning_of_week
    inicio_mes    = hoy.beginning_of_month
    sedes_ids     = usuario.sedes_visibles_ids

    mias = Dispensacion.no_canceladas.joins(stock: :sede)
                       .where(sedes: { club_id: club.id })
                       .where(user_id: usuario.id)

    stocks = Stock.joins(:sede)
                  .where(sedes: { club_id: club.id, id: sedes_ids })
                  .disponibles.asignados.includes(:lote)

    umbral = club.umbral_stock_g.to_f
    stocks_data = stocks.group_by(&:forma_producto).map do |forma, ss|
      total = ss.sum { |s| s.cantidad.to_f }
      { forma: forma, cantidad_g: total.round(2), alerta: forma == 'flor_seca' && total < umbral }
    end.sort_by { |s| s[:cantidad_g] }

    # Sus pacientes del mes. Sin los dígitos del DNI: en el mostrador no ayudan a reconocer a
    # nadie —la persona está enfrente— y son un dato identificatorio que no hace falta servir.
    top_pacientes = mias
      .where(fecha_dispensacion: inicio_mes..hoy)
      .includes(:paciente)
      .group(:paciente_id)
      .select('paciente_id, SUM(dispensaciones.cantidad) AS total_g, COUNT(*) AS dispens_count')
      .order('total_g DESC')
      .limit(10)
      .map { |r| { paciente: r.paciente&.nombre_completo, total_g: r.total_g.to_f.round(2),
                   dispens_count: r.dispens_count } }

    # Una reserva la prepara quien está atendiendo, no necesariamente quien la tomó: el corte
    # es por SEDE, no por persona.
    reservas_scope = Reserva.where(club_id: club.id).pendientes
                            .joins(:stock).where(stocks: { sede_id: sedes_ids })
    por_preparar = reservas_scope.where('fecha_entrega_estimada <= ?', hoy)
                                 .includes(:paciente, :stock, items: :stock).order(fecha_entrega_estimada: :asc)

    {
      alcance: 'propio',
      # El mostrador cuya caja le corresponde. CUÁL ES "MI MOSTRADOR" LO CONTESTA
      # `User#sede_de_mostrador` y nadie más: acá se tomaba la primera sede asignada por nombre, sin
      # mirar el tipo, así que un dispensador con «Finca Norte» (producción) asignada veía en su
      # inicio "Esta sede no dispensa: no tiene mostrador" mientras la pantalla del mostrador —que
      # sí pregunta bien— le mostraba la caja abierta con 643 g arriba. La misma regla en dos
      # lugares, y el inicio contradiciendo a la pantalla de al lado.
      sede_mostrador: sede_de_mostrador_de(usuario),
      resumen: {
        dispensaciones_hoy:    mias.where(fecha_dispensacion: hoy..hoy).count,
        gramos_hoy:            mias.where(fecha_dispensacion: hoy..hoy).sum(:cantidad).to_f.round(2),
        dispensaciones_semana: mias.where(fecha_dispensacion: inicio_semana..hoy).count,
        gramos_semana:         mias.where(fecha_dispensacion: inicio_semana..hoy).sum(:cantidad).to_f.round(2),
        dispensaciones_mes:    mias.where(fecha_dispensacion: inicio_mes..hoy).count,
        gramos_mes:            mias.where(fecha_dispensacion: inicio_mes..hoy).sum(:cantidad).to_f.round(2),
      },
      stocks:        stocks_data,
      top_pacientes: top_pacientes,
      por_dia:       (6.days.ago.to_date..hoy).map { |d|
        { fecha: d.strftime('%d/%m'), count: mias.where(fecha_dispensacion: d).count }
      },
      reservas: {
        hoy:      por_preparar.where(fecha_entrega_estimada: hoy).count,
        vencidas: por_preparar.where('fecha_entrega_estimada < ?', hoy).count,
        total:    por_preparar.count,
        lista:    por_preparar.limit(20).map { |r| serializar_reserva_por_preparar(r, hoy) },
      },
    }
  end

  def serializar_reserva_por_preparar(r, hoy)
    {
      id:             r.id,
      paciente:       r.paciente ? "#{r.paciente.nombre} #{r.paciente.apellido}".strip : '—',
      fecha:          r.fecha_entrega_estimada,
      vencida:        r.fecha_entrega_estimada < hoy,
      forma_producto: r.stock&.forma_producto,
      cantidad:       r.cantidad.to_f,
      detalle:        r.descripcion_items,
      productos:      r.items.size,
      sena_ars:       r.sena_ars.to_f,
      resta_ars:      r.aporte_restante_ars.to_f,
    }
  end

  def calcular_dispensador(club)
    hoy    = Time.zone.today
    inicio_semana = hoy.beginning_of_week
    inicio_mes    = hoy.beginning_of_month

    # Scope dispensaciones del club
    base_disps = Dispensacion.no_canceladas.joins(stock: :sede)
                             .where(sedes: { club_id: club.id })

    disps_hoy     = base_disps.where(fecha_dispensacion: hoy..hoy)
    disps_semana  = base_disps.where(fecha_dispensacion: inicio_semana..hoy)
    disps_mes     = base_disps.where(fecha_dispensacion: inicio_mes..hoy)

    # Stock por producto
    stocks = Stock.joins(:sede)
                  .where(sedes: { club_id: club.id })
                  .disponibles
                  .asignados
                  .includes(:lote)

    stock_bajo_umbral = club.umbral_stock_g.to_f
    stocks_data = stocks.group_by(&:forma_producto).map do |forma, ss|
      total = ss.sum { |s| s.cantidad.to_f }
      # "Stock bajo" solo aplica a flor seca; los derivados son inventario, no disparan alerta.
      { forma: forma, cantidad_g: total.round(2), alerta: forma == 'flor_seca' && total < stock_bajo_umbral }
    end.sort_by { |s| s[:cantidad_g] }

    # Pacientes REPROCANN por vencer
    pacientes = Paciente.for_club(club.id)
    reprocann_por_vencer = pacientes.reprocann_por_vencer.count
    reprocann_vencidos   = pacientes.where('reprocann_vencimiento < ?', hoy).count

    # Top pacientes del mes
    top_pacientes = base_disps
      .where(fecha_dispensacion: inicio_mes..hoy)
      .includes(:paciente)
      .group(:paciente_id)
      .select('paciente_id, SUM(dispensaciones.cantidad) AS total_g, COUNT(*) AS dispens_count')
      .order('total_g DESC')
      .limit(10)
      .map do |r|
        p = r.paciente
        {
          # Nombre completo: quien mira la analítica ya tiene acceso a la ficha del paciente,
          # así que la inicial no protegía nada y hacía ilegible el ranking.
          paciente:       p&.nombre_completo,
          iniciales:      "#{p&.nombre&.[](0)}.#{p&.apellido&.[](0)}.",
          dni_last4:      p&.dni_normalizado.to_s.last(4),
          total_g:        r.total_g.to_f.round(2),
          dispens_count:  r.dispens_count,
        }
      end

    por_dia = (6.days.ago.to_date..Time.zone.today).map do |date|
      { fecha: date.strftime('%d/%m'), count: base_disps.where(fecha_dispensacion: date).count }
    end

    # Reservas a preparar: pendientes con fecha de entrega <= hoy (las de hoy + las vencidas).
    reservas_scope = Reserva.where(club_id: club.id).pendientes
    reservas_por_preparar = reservas_scope.where('fecha_entrega_estimada <= ?', hoy)
                                          .includes(:paciente, :stock, items: :stock)
                                          .order(fecha_entrega_estimada: :asc)
    reservas_lista = reservas_por_preparar.limit(20).map do |r|
      {
        id:             r.id,
        paciente:       r.paciente ? "#{r.paciente.nombre} #{r.paciente.apellido}".strip : '—',
        fecha:          r.fecha_entrega_estimada,
        vencida:        r.fecha_entrega_estimada < hoy,
        forma_producto: r.stock&.forma_producto,
        cantidad:       r.cantidad.to_f,
        # Qué preparar, línea por línea: «5g de Critical · 2u de OG». La fila sola era la primera.
        detalle:        r.descripcion_items,
        productos:      r.items.size,
        sena_ars:       r.sena_ars.to_f,
        resta_ars:      r.aporte_restante_ars.to_f,
      }
    end

    {
      alcance: 'club',
      # Misma regla que arriba: una sede que atienda público, no la primera por nombre.
      sede_mostrador: sede_de_mostrador_de(current_user),
      resumen: {
        dispensaciones_hoy:    disps_hoy.count,
        gramos_hoy:            disps_hoy.sum(:cantidad).to_f.round(2),
        dispensaciones_semana: disps_semana.count,
        gramos_semana:         disps_semana.sum(:cantidad).to_f.round(2),
        dispensaciones_mes:    disps_mes.count,
        gramos_mes:            disps_mes.sum(:cantidad).to_f.round(2),
      },
      reprocann: {
        por_vencer: reprocann_por_vencer,
        vencidos:   reprocann_vencidos,
      },
      stocks:        stocks_data,
      top_pacientes: top_pacientes,
      por_dia:       por_dia,
      # Entregas de delivery abiertas HOY: lo que el admin mira desde el celular para saber si el
      # día se está despachando o si algo quedó trabado.
      entregas_hoy: Dispensacion.no_canceladas.joins(stock: :sede)
                                .where(sedes: { club_id: club.id })
                                .where(estado_envio: %w[pendiente en_viaje]).count,
      reservas: {
        hoy:      reservas_por_preparar.where(fecha_entrega_estimada: hoy).count,
        vencidas: reservas_por_preparar.where('fecha_entrega_estimada < ?', hoy).count,
        total:    reservas_por_preparar.count,
        lista:    reservas_lista,
      },
    }
  end

  # ── ANALÍTICA: cuatro solapas, una pregunta cada una (rediseño de sep-2026, decisiones de
  # Germán sobre el artifact). Todas sobre el mismo universo —lotes cerrados con rendimiento,
  # cosechados en el período elegido, TODO el historial por defecto— y el cálculo vive en
  # `app/services/analitica/*`. Reemplazan a rendimiento_genetica, produccion,
  # correlacion_ambiental, comparativa_salas y costo_por_gramo_sede, que contaban mal (merma
  # siempre 0, una fase `secado` que no existe, el costo de lotes abiertos dividido por gramos de
  # cerrados) o repetían informes.

  # GET /api/analytics/geneticas
  def geneticas
    render json: { periodo: periodo_analitica_etiqueta, filas: Analitica::Geneticas.new(universo).call }
  end

  # GET /api/analytics/fases
  def fases
    render json: { periodo: periodo_analitica_etiqueta, fases: Analitica::Universo::FASES,
                   filas: Analitica::Fases.new(universo).call }
  end

  # GET /api/analytics/donde_y_como?corte=sala|metodo|luz
  def donde_y_como
    render json: Analitica::DondeYComo.new(universo, corte: params[:corte]).call
                                      .merge(periodo: periodo_analitica_etiqueta)
  end

  # GET /api/analytics/costo
  def costo
    render json: Analitica::Costo.new(universo).call.merge(periodo: periodo_analitica_etiqueta)
  end

  # GET /api/analytics/ejecutivo
  # Resumen anual — KPIs del año en curso vs año anterior
  def ejecutivo
    club         = current_user.club
    año_actual   = Time.zone.today.year
    año_anterior = año_actual - 1
    cache_key    = "analytics/ejecutivo/#{club.id}/#{año_actual}/#{analytics_stamp(club)}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      { año: año_actual, actual: kpis_anuales(club, año_actual), anterior: kpis_anuales(club, año_anterior) }
    end
    render json: data
  end

  # GET /api/analytics/pl_lotes
  # Para: admin, supervisor
  def pl_lotes
    club      = current_user.club
    cache_key = "analytics/pl_lotes/#{club.id}/#{analytics_stamp(club)}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      calcular_pl_lotes(club)
    end
    render json: data
  end

  def kpis_anuales(club, año)
    inicio = Date.new(año, 1, 1)
    fin    = Date.new(año, 12, 31)

    lotes_año = club.lotes
                    .where("EXTRACT(YEAR FROM COALESCE(start_date, created_at::date)) = ?", año)

    gramos_producidos = lotes_año.where.not(rendimiento_real_g: nil)
                                 .sum(:rendimiento_real_g).to_f.round(2)
    ciclos_cerrados   = lotes_año.where(estado: 'finalizado').count

    base_disps = Dispensacion.no_canceladas.joins(:stock)
                             .where(stocks: { club_id: club.id })
                             .where(fecha_dispensacion: inicio..fin)

    # Ingresos = libro contable de caja (MISMA definición que el dashboard de Negocio):
    # incluye recupero por dispensación Y señas/aportes, excluye crédito impago. Antes
    # se recomputaba desde Dispensacion (solo facturación), lo que dejaba las señas
    # afuera y contradecía el KPI mensual ("10000 arriba / sin ingresos abajo").
    ingresos           = MovimientoContable.ingresos.where(club_id: club.id)
                                           .where(fecha: inicio..fin).sum(:monto_ars).to_f.round(2)
    gramos_dispensados = base_disps.sum(:cantidad).to_f.round(2)

    costo_total = CostoLote.joins(:lote)
                           .where(lotes: { club_id: club.id })
                           .where("EXTRACT(YEAR FROM COALESCE(lotes.start_date, lotes.created_at::date)) = ?", año)
                           .sum(:costo_total).to_f.round(2)

    margen     = (ingresos - costo_total).round(2)
    margen_pct = ingresos > 0 ? (margen / ingresos * 100).round(1) : nil

    {
      gramos_producidos:,
      gramos_dispensados:,
      ingresos:,
      costo_total:,
      margen:,
      margen_pct:,
      ciclos_cerrados:,
    }
  end

  def calcular_pl_lotes(club)
    lotes = club.lotes.includes(:genetica, :costo_lote).order(created_at: :desc)

    ingresos_por_lote = Dispensacion.no_canceladas
      .joins(:stock)
      .where(stocks: { club_id: club.id })
      .where.not(stocks: { lote_id: nil })
      .group('stocks.lote_id')
      .sum('dispensaciones.cantidad * COALESCE(dispensaciones.precio_unitario_ars, 0)')

    gramos_disp_por_lote = Dispensacion.no_canceladas
      .joins(:stock)
      .where(stocks: { club_id: club.id })
      .where.not(stocks: { lote_id: nil })
      .group('stocks.lote_id')
      .sum(:cantidad)

    filas = lotes.map do |l|
      c           = l.costo_lote
      ingresos    = ingresos_por_lote[l.id].to_f.round(2)
      costo_total = c&.costo_total.to_f
      margen      = (ingresos - costo_total).round(2)
      margen_pct  = ingresos > 0 ? (margen / ingresos * 100).round(1) : nil
      gramos_disp = gramos_disp_por_lote[l.id].to_f.round(3)
      {
        id:                 l.id,
        codigo:             l.codigo,
        genetica:           l.genetica&.nombre,
        estado:             l.estado,
        costo_total:        costo_total,
        costo_por_gramo:    c&.costo_por_gramo&.to_f,
        ingresos:           ingresos,
        gramos_dispensados: gramos_disp,
        ingreso_por_gramo:  gramos_disp > 0 ? (ingresos / gramos_disp).round(2) : nil,
        margen:             margen,
        margen_pct:         margen_pct,
        tiene_costos:       c.present?,
        tiene_ingresos:     ingresos > 0,
      }
    end

    { lotes: filas }
  end

  # GET /api/analytics/contabilidad
  # P&L mensual últimos 12 meses + proyección de lotes en curso
  def contabilidad
    club = current_user.club
    cache_key = "analytics/contabilidad/#{club.id}/#{analytics_stamp(club)}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      calcular_contabilidad(club)
    end

    respond_to do |format|
      format.json { render json: data }
      # PDF y Excel de servidor: el P&L se bajaba como captura de pantalla.
      format.pdf  { send_data pl_documento(data).render,
                              filename: "PL_produccion_#{Time.zone.today.strftime('%Y%m%d')}.pdf",
                              type: 'application/pdf', disposition: 'attachment' }
      format.xlsx { send_data pl_xlsx(data),
                              filename: "PL_produccion_#{Time.zone.today.strftime('%Y%m%d')}.xlsx",
                              type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                              disposition: 'attachment' }
    end
  end

  # GET /api/analytics/comparativa_salas
  # GET /api/analytics/comparativa_salas — el resumen por sala que muestra la pantalla de Salas
  # (ciclos cerrados, gramos, últimas lecturas). No es de la analítica: es de Salas.
  def comparativa_salas
    club     = current_user.club
    sala_ids = club.salas.pluck(:id)

    # Agregados por sala en una sola consulta
    stats_por_sala = Lote
      .where(sala_id: sala_ids, estado: 'finalizado')
      .group(:sala_id)
      .select(
        :sala_id,
        'COUNT(*) AS ciclos',
        'COALESCE(SUM(rendimiento_real_g), 0) AS total_g',
        'COALESCE(SUM(plants_count_cosechadas), 0) AS total_plantas',
      ).index_by(&:sala_id)

    # Días promedio usando lote_eventos (fecha real de finalización)
    dias_por_sala = LoteEvento
      .joins(:lote)
      .where(lotes: { sala_id: sala_ids })
      .where(tipo: 'cambio_estado', estado_nuevo: 'finalizado')
      .where.not('lotes.start_date': nil)
      .select("lotes.sala_id, AVG((lote_eventos.registrado_en::date - lotes.start_date)) AS dias_prom")
      .group('lotes.sala_id')
      .index_by(&:sala_id)

    activos_por_sala = Lote
      .where(sala_id: sala_ids)
      .where.not(estado: 'finalizado')
      .group(:sala_id)
      .count

    ultimas_lecturas = LecturaAmbiental
      .where(sala_id: sala_ids, tipo: %w[temperatura humedad co2])
      .where('medido_at >= ?', 24.hours.ago)
      .order(:sala_id, :tipo, medido_at: :desc)
      .select('DISTINCT ON (sala_id, tipo) sala_id, tipo, valor, medido_at')

    lecturas_por_sala = ultimas_lecturas.each_with_object({}) do |l, h|
      h[l.sala_id] ||= {}
      h[l.sala_id][l.tipo] = l.valor.to_f
    end

    salas = club.salas.order(:nombre)

    filas = salas.map do |sala|
      st          = stats_por_sala[sala.id]
      ciclos      = st&.ciclos.to_i
      total_g     = st&.total_g.to_f
      total_pls   = st&.total_plantas.to_i
      kg_producidos = total_g / 1000.0
      kg_por_planta = total_pls > 0 ? (total_g / total_pls / 1000.0).round(3) : nil
      dias_avg      = dias_por_sala[sala.id]&.dias_prom
      dias_promedio = dias_avg ? dias_avg.to_f.round(0).to_i : nil
      ambiental     = lecturas_por_sala[sala.id] || {}

      {
        id:             sala.id,
        nombre:         sala.nombre,
        tipo:           sala.tipo,
        ciclos:         ciclos,
        kg_producidos:  kg_producidos.round(3),
        kg_por_planta:  kg_por_planta,
        dias_promedio:  dias_promedio,
        lotes_activos:  activos_por_sala[sala.id] || 0,
        temperatura:    ambiental['temperatura'],
        humedad:        ambiental['humedad'],
        co2:            ambiental['co2'],
      }
    end

    render json: { salas: filas }
  end

  # El período de la analítica: el mismo selector que los informes (`periodo` o `desde`/`hasta`),
  # pero con «todo» como default: para comparar hacen falta muchos lotes.
  def universo
    @universo ||= begin
      desde, hasta = periodo_analitica
      Analitica::Universo.new(club: current_user.club, desde: desde, hasta: hasta)
    end
  end

  def periodo_analitica
    if params[:desde].present?
      desde = Date.parse(params[:desde].to_s)
      hasta = params[:hasta].present? ? Date.parse(params[:hasta].to_s) : Time.zone.today
      desde, hasta = hasta, desde if hasta < desde
      return [desde.beginning_of_day, hasta.end_of_day]
    end
    rango = InformesController::PERIODO_RANGOS[params[:periodo].to_s]
    return [nil, nil] if rango.nil?

    d, h = rango.call
    [d.to_date.beginning_of_day, h.to_date.end_of_day]
  rescue Date::Error
    [nil, nil]
  end

  def periodo_analitica_etiqueta
    desde, hasta = periodo_analitica
    return { desde: nil, hasta: nil, etiqueta: 'todo el historial', lotes: universo.lotes.size } if desde.nil?

    { desde: desde.to_date, hasta: hasta.to_date,
      etiqueta: "cosechados entre el #{desde.strftime('%d/%m/%Y')} y el #{hasta.strftime('%d/%m/%Y')}",
      lotes: universo.lotes.size }
  end

  def require_analytics_access!
    unless %w[admin supervisor super_admin].include?(current_user.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  # Sello que cambia ante CUALQUIER mutación que afecte los números de la analítica
  # financiera/productiva del club: libro contable, costos de lote y lotes. Al
  # incluirlo en la cache key, la analítica se auto-invalida en el instante en que
  # cambian los datos (alta/edición/anulación de seña, dispensación, costo, fase de
  # lote) — sin callbacks ni busts manuales. El TTL queda como respaldo. Son 3
  # agregados baratos (max(updated_at) + count) sobre columnas indexadas por club.
  def analytics_stamp(club)
    mov = MovimientoContable.where(club_id: club.id)
    cl  = CostoLote.joins(:lote).where(lotes: { club_id: club.id })
    lo  = club.lotes
    [
      mov.maximum(:updated_at)&.to_i, mov.count,
      cl.maximum(:updated_at)&.to_i,  cl.count,
      lo.maximum(:updated_at)&.to_i,  lo.count,
    ].join('-')
  end

  def require_dispensador_access!
    unless %w[admin dispensador super_admin].include?(current_user.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  # El P&L como documento: meses arriba (que es la lectura del negocio) y la proyección de
  # los lotes en curso abajo, separada, porque son números estimados y no realizados.
  def pl_secciones(data)
    meses = Array(data[:meses] || data['meses'])
    proy  = Array(data[:proyeccion_lotes] || data['proyeccion_lotes'])
    secciones = [{
      titulo: 'Resultado por mes',
      headers: ['Mes', 'Ingresos', 'Costos', 'Margen'],
      rows: meses.map { |m| [m[:mes], m[:ingresos], m[:costos], m[:margen]] },
      formatos: [:texto, :moneda, :moneda, :moneda],
      totales: [1, 2, 3],
      aligns: { 1 => :right, 2 => :right, 3 => :right },
    }]
    if proy.any?
      secciones << {
        titulo: 'Proyección de lotes en curso',
        headers: ['Lote', 'Genética', 'Rendimiento objetivo (g)', 'Ingreso estimado'],
        rows: proy.map { |l| [l[:codigo], l[:genetica], l[:rendimiento_objetivo_g], l[:ingreso_estimado] || '—'] },
        aligns: { 2 => :right, 3 => :right },
      }
    end
    secciones
  end

  def pl_kpis(data)
    meses = Array(data[:meses] || data['meses'])
    [
      { label: 'Ingresos',  valor: meses.sum { |m| m[:ingresos].to_f }.round(2), tono: :ok },
      { label: 'Costos',    valor: meses.sum { |m| m[:costos].to_f }.round(2) },
      { label: 'Margen',    valor: meses.sum { |m| m[:margen].to_f }.round(2) },
      { label: 'Proyectado', valor: (data[:ingreso_proy_total] || data['ingreso_proy_total']).to_f.round(2), tono: :warn },
    ]
  end

  def pl_documento(data)
    InformeDocument.new(club: current_user.club, usuario: current_user,
                        titulo: 'Resultado de producción (P&L)',
                        kpis: pl_kpis(data), secciones: pl_secciones(data), tipo_code: 'PL',
                        nota: 'La proyección estima el ingreso de los lotes en curso con el precio por gramo del último lote cerrado de la misma genética. No es dinero realizado.')
  end

  def pl_xlsx(data)
    principal = pl_secciones(data).first
    XlsxExport.new(club: current_user.club, titulo: 'Resultado de producción (P&L)',
                   headers: principal[:headers], rows: principal[:rows],
                   formatos: principal[:formatos], totales: principal[:totales],
                   resumen: pl_kpis(data).to_h { |k| [k[:label], k[:valor]] }).render
  end

  def calcular_contabilidad(club)
    hoy   = Time.zone.today
    inicio = (hoy - 11.months).beginning_of_month

    # P&L mensual — agrupado por mes
    meses = []
    (0..11).each do |i|
      mes_ini = (hoy - i.months).beginning_of_month
      mes_fin = mes_ini.end_of_month
      label   = mes_ini.strftime('%b %Y')

      # El resultado del mes sale ENTERO del libro de caja: ingresos menos egresos, que es lo
      # que el admin ve en la pantalla de Contabilidad.
      #
      # Antes los ingresos salían del libro y los "costos" de CostoLote (costos imputados a
      # lotes). Dos libros distintos restados entre sí: el margen no coincidía con nada, y los
      # egresos del libro —un alquiler, un sueldo— no aparecían en ninguna parte del informe.
      ingresos = MovimientoContable.ingresos.where(club_id: club.id)
                                   .where(fecha: mes_ini..mes_fin).sum(:monto_ars).to_f.round(2)
      egresos  = MovimientoContable.egresos.where(club_id: club.id)
                                  .where(fecha: mes_ini..mes_fin).sum(:monto_ars).to_f.round(2)

      # El costo de producción va APARTE: es cuánto costó producir lo cosechado, no plata que
      # salió de la caja este mes. Mezclarlo con el resultado del período es lo que hacía que
      # el informe dijera una cosa y la pantalla otra.
      costo_produccion = CostoLote.joins(:lote)
                                  .where(lotes: { club_id: club.id })
                                  .where(created_at: mes_ini..mes_fin.end_of_day)
                                  .sum(:costo_total).to_f.round(2)

      meses.unshift({ mes: label, mes_ini: mes_ini, ingresos: ingresos, costos: egresos,
                      margen: (ingresos - egresos).round(2), costo_produccion: costo_produccion })
    end

    # Proyección: lotes en curso (vegetativo / floración) × precio sugerido × rendimiento objetivo
    estados_en_curso = Lote::ESTADOS - ['finalizado']
    lotes_activos = club.lotes
                        .where(estado: estados_en_curso)
                        .where.not(rendimiento_objetivo_g: nil)

    proyeccion_items = lotes_activos.map do |l|
      precio_g = club.lotes
                     .joins(:costo_lote)
                     .where(genetica_id: l.genetica_id)
                     .where.not(rendimiento_real_g: nil)
                     .order(created_at: :desc)
                     .first
                     &.then { |ref| ref.rendimiento_real_g > 0 ? (CostoLote.find_by(lote: ref)&.costo_total.to_f / ref.rendimiento_real_g) : nil }

      ingreso_estimado = precio_g ? (l.rendimiento_objetivo_g * precio_g).round(2) : nil

      {
        lote_id:              l.id,
        codigo:               l.codigo,
        estado:               l.estado,
        genetica:             l.genetica&.nombre,
        rendimiento_obj_g:    l.rendimiento_objetivo_g.to_f,
        precio_g_estimado:    precio_g&.round(2),
        ingreso_estimado:     ingreso_estimado,
        fecha_cosecha_est:    l.fecha_cosecha_estimada,
      }
    end

    ingreso_proy_total = proyeccion_items.sum { |p| p[:ingreso_estimado] || 0 }.round(2)

    {
      meses:                meses,
      proyeccion_lotes:     proyeccion_items,
      ingreso_proy_total:   ingreso_proy_total,
    }
  end

  private :calcular_dispensador, :calcular_pl_lotes, :kpis_anuales, :calcular_contabilidad,
          :universo, :periodo_analitica, :periodo_analitica_etiqueta,
          :require_analytics_access!, :require_dispensador_access!
end
