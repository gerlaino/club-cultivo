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
  def rendimiento_genetica
    club = current_user.club
    año  = params[:año].presence
    cache_key = "analytics/rendimiento_genetica/#{club.id}/#{año || 'all'}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      calcular_rendimiento_genetica(club, año: año)
    end
    render json: data
  end

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

  def calcular_rendimiento_genetica(club, año: nil)
    lotes = club.lotes.where.not(estado: 'enraizado').includes(:genetica)
    lotes = lotes.where('EXTRACT(YEAR FROM COALESCE(start_date, created_at)) = ?', año) if año

    # Rendimiento por genética (solo lotes con datos reales)
    por_genetica = lotes.group_by { |l| l.genetica_id }.filter_map do |gid, ls|
      genetica = ls.first&.genetica
      next unless genetica

      con_rendimiento = ls.select { |l| l.rendimiento_real_g.present? }
      rendimiento_avg = con_rendimiento.any? ? (con_rendimiento.sum { |l| l.rendimiento_real_g.to_f } / con_rendimiento.size).round(1) : nil

      objetivo_avg = begin
        obj = ls.select { |l| l.rendimiento_objetivo_g.present? }
        obj.any? ? (obj.sum { |l| l.rendimiento_objetivo_g.to_f } / obj.size).round(1) : nil
      end

      merma_avg = begin
        con_merma = ls.select { |l| l.plants_count.present? && l.plants_count_cosechadas.present? && l.plants_count > 0 }
        if con_merma.any?
          mermas = con_merma.map { |l| ((l.plants_count - l.plants_count_cosechadas).to_f / l.plants_count * 100).round(1) }
          (mermas.sum / mermas.size).round(1)
        end
      end

      con_ambos     = ls.select { |l| l.rendimiento_real_g.present? && l.plants_count.present? && l.plants_count > 0 }
      g_por_planta  = con_ambos.any? ? (con_ambos.sum { |l| l.rendimiento_real_g.to_f / l.plants_count } / con_ambos.size).round(1) : nil

      {
        genetica_id:          gid,
        nombre:               genetica.nombre,
        lotes_total:          ls.size,
        lotes_finalizados:    ls.count { |l| l.rendimiento_real_g.present? },
        rendimiento_promedio: rendimiento_avg,
        objetivo_promedio:    objetivo_avg,
        desviacion_promedio:  rendimiento_avg && objetivo_avg ? ((rendimiento_avg - objetivo_avg) / objetivo_avg * 100).round(1) : nil,
        merma_promedio_pct:   merma_avg,
        g_por_planta:         g_por_planta,
        lotes_activos:        ls.count { |l| !%w[enraizado finalizado].include?(l.estado) },
      }
    end.sort_by { |r| [-(r[:rendimiento_promedio] || 0)] }

    # Top lotes recientes
    lotes_recientes = club.lotes
                          .includes(:genetica)
                          .where.not(estado: %w[enraizado])
                          .order(created_at: :desc)
                          .limit(20)
                          .map do |l|
      {
        id:                  l.id,
        codigo:              l.codigo,
        estado:              l.estado,
        genetica:            l.genetica&.nombre,
        plants_count:        l.plants_count,
        rendimiento_real_g:  l.rendimiento_real_g&.to_f,
        rendimiento_obj_g:   l.rendimiento_objetivo_g&.to_f,
        g_por_planta:        l.rendimiento_real_g && l.plants_count.to_i > 0 ? (l.rendimiento_real_g.to_f / l.plants_count).round(1) : nil,
        desv_pct:            l.rendimiento_real_g && l.rendimiento_objetivo_g ? ((l.rendimiento_real_g.to_f - l.rendimiento_objetivo_g.to_f) / l.rendimiento_objetivo_g.to_f * 100).round(1) : nil,
        created_at:          l.created_at,
      }
    end

    # Resumen global
    lotes_finalizados = lotes.select { |l| l.rendimiento_real_g.present? }
    rendimiento_global = lotes_finalizados.any? ? (lotes_finalizados.sum { |l| l.rendimiento_real_g.to_f } / lotes_finalizados.size).round(1) : nil

    {
      resumen: {
        lotes_totales:        lotes.count,
        lotes_finalizados:    lotes_finalizados.size,
        geneticas_activas:    por_genetica.count { |g| g[:lotes_activos] > 0 },
        rendimiento_global_g: rendimiento_global,
      },
      por_genetica:    por_genetica,
      lotes_recientes: lotes_recientes,
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
  # Estado de la caja de cada mostrador, para el tablero del admin.
  #
  # `Sede::SUITES_POR_TIPO` ya dice qué sede dispensa: `social` y `mixta`. Una de producción no
  # tiene mostrador y ofrecerle una caja sería ruido — la regla no se reescribe acá.
  def cajas_por_sede(club)
    sedes = club.sedes.activas.where(tipo: %w[social mixta]).order(:nombre).to_a
    return [] if sedes.empty?

    activas = CajaTurno.where(club_id: club.id, punto_type: 'Sede', punto_id: sedes.map(&:id))
                       .activas.includes(:abierta_por).index_by(&:punto_id)

    sedes.map do |sede|
      caja = activas[sede.id]
      {
        sede_id: sede.id,
        sede:    sede.nombre,
        # `sin_abrir` no es un estado de la caja: es la AUSENCIA de caja, y es justo lo que el
        # admin necesita ver de un vistazo.
        estado:  caja.nil? ? 'sin_abrir' : (caja.apertura_confirmada? ? caja.estado : 'sin_confirmar'),
        caja_id:                caja&.id,
        abierta_por:            caja&.abierta_por&.nombre_completo,
        abierta_at:             caja&.abierta_at,
        efectivo_esperado_ars:  caja&.efectivo_esperado_ars,
        efectivo_declarado_ars: caja&.efectivo_declarado_ars&.to_f,
        diferencia_ars:         caja&.diferencia_ars,
      }
    end
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
                                 .includes(:paciente, :stock).order(fecha_entrega_estimada: :asc)

    {
      alcance: 'propio',
      # El mostrador cuya caja le corresponde. Con varias sedes asignadas se toma la primera:
      # una persona atiende un mostrador por turno, y elegir cuál es una pregunta que hoy nadie
      # se hace. Si algún día se turnan entre sedes, acá va el selector.
      sede_mostrador: (Sede.where(id: sedes_ids).order(:nombre).first&.then { |x| { id: x.id, nombre: x.nombre } }),
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
                                          .includes(:paciente, :stock)
                                          .order(fecha_entrega_estimada: :asc)
    reservas_lista = reservas_por_preparar.limit(20).map do |r|
      {
        id:             r.id,
        paciente:       r.paciente ? "#{r.paciente.nombre} #{r.paciente.apellido}".strip : '—',
        fecha:          r.fecha_entrega_estimada,
        vencida:        r.fecha_entrega_estimada < hoy,
        forma_producto: r.stock&.forma_producto,
        cantidad:       r.cantidad.to_f,
        sena_ars:       r.sena_ars.to_f,
        resta_ars:      r.aporte_restante_ars.to_f,
      }
    end

    {
      alcance: 'club',
      sede_mostrador: (club.sedes.order(:nombre).first&.then { |x| { id: x.id, nombre: x.nombre } }),
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

  # GET /api/analytics/correlacion_ambiental
  # Para: admin, supervisor, super_admin
  def correlacion_ambiental
    club = current_user.club
    año  = params[:año].presence
    cache_key = "analytics/correlacion_ambiental/#{club.id}/#{año || 'all'}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      calcular_correlacion_ambiental(club, año: año)
    end
    render json: data
  end

  # GET /api/analytics/produccion
  # Para: admin, supervisor, super_admin
  def produccion
    club = current_user.club
    año  = params[:año].presence
    cache_key = "analytics/produccion/#{club.id}/#{año || 'all'}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      calcular_produccion(club, año: año)
    end
    render json: data
  end

  TIPOS_CORRELACION = %w[temperatura humedad vpd ph co2 ec ppfd].freeze

  VPD_BUCKETS = [
    [nil,  0.8, 'Bajo (<0.8 kPa)'],
    [0.8,  1.2, 'Óptimo bajo (0.8–1.2 kPa)'],
    [1.2,  1.6, 'Óptimo (1.2–1.6 kPa)'],
    [1.6,  2.0, 'Alto (1.6–2.0 kPa)'],
    [2.0,  nil, 'Muy alto (>2.0 kPa)'],
  ].freeze

  TEMP_BUCKETS = [
    [nil,  20.0, 'Frío (<20°C)'],
    [20.0, 23.0, 'Fresco (20–23°C)'],
    [23.0, 26.0, 'Óptimo (23–26°C)'],
    [26.0, 29.0, 'Cálido (26–29°C)'],
    [29.0, nil,  'Caliente (>29°C)'],
  ].freeze

  PH_BUCKETS = [
    [nil, 5.8, 'Ácido (<5.8)'],
    [5.8, 6.2, 'Óptimo (5.8–6.2)'],
    [6.2, 6.8, 'Normal (6.2–6.8)'],
    [6.8, nil, 'Alcalino (>6.8)'],
  ].freeze

  def calcular_correlacion_ambiental(club, año: nil)
    lotes = club.lotes
                .where(estado: 'finalizado')
                .where.not(rendimiento_real_g: nil)
                .includes(:genetica)
    lotes = lotes.where('EXTRACT(YEAR FROM COALESCE(start_date, created_at)) = ?', año) if año

    # Precarga lecturas en memoria agrupadas por lote para evitar N+1
    lote_ids = lotes.map(&:id)
    lecturas_por_lote = LecturaAmbiental
      .where(lote_id: lote_ids)
      .group_by(&:lote_id)

    lotes_data = lotes.filter_map do |l|
      lecturas = lecturas_por_lote[l.id] || []
      next if lecturas.empty?

      promedios = TIPOS_CORRELACION.each_with_object({}) do |tipo, h|
        vals = lecturas.select { |r| r.tipo == tipo }.map { |r| r.valor.to_f }
        h[tipo.to_sym] = vals.any? ? (vals.sum / vals.size).round(2) : nil
      end
      next if promedios.values.all?(&:nil?)

      rend = l.rendimiento_real_g.to_f
      obj  = l.rendimiento_objetivo_g&.to_f

      {
        lote_id:       l.id,
        codigo:        l.codigo,
        genetica:      l.genetica&.nombre,
        rendimiento_g: rend,
        objetivo_g:    obj,
        desv_pct:      (obj && obj > 0) ? ((rend - obj) / obj * 100).round(1) : nil,
        n_registros:   lecturas.size,
        **promedios,
      }
    end.sort_by { |l| -(l[:rendimiento_g] || 0) }

    regresiones = TIPOS_CORRELACION.each_with_object({}) do |tipo, h|
      pairs = lotes_data.filter_map { |l| v = l[tipo.to_sym]; [v, l[:rendimiento_g]] if v }
      h[tipo.to_sym] = regresion_lineal(pairs.map(&:first), pairs.map(&:last))
    end

    {
      lotes:            lotes_data,
      vpd_buckets:      agrupar_buckets(lotes_data, :vpd,         VPD_BUCKETS),
      temp_buckets:     agrupar_buckets(lotes_data, :temperatura,  TEMP_BUCKETS),
      ph_buckets:       agrupar_buckets(lotes_data, :ph,           PH_BUCKETS),
      regresiones:,
      total_con_datos:  lotes_data.size,
      total_finalizados: lotes.count,
    }
  end

  def agrupar_buckets(lotes_data, campo, rangos)
    rangos.filter_map do |min, max, label|
      subset = lotes_data.select do |l|
        v = l[campo]
        next false if v.nil?
        (min.nil? || v >= min) && (max.nil? || v < max)
      end
      next if subset.empty?

      con_desv = subset.select { |l| l[:desv_pct] }
      {
        label:    label,
        count:    subset.size,
        rend_avg: (subset.sum { |l| l[:rendimiento_g] } / subset.size).round(1),
        desv_avg: con_desv.any? ? (con_desv.sum { |l| l[:desv_pct] } / con_desv.size).round(1) : nil,
      }
    end
  end

  def calcular_produccion(club, año: nil)
    lotes = club.lotes.includes(:genetica, :plants).where.not(estado: 'enraizado')
    lotes = lotes.where('EXTRACT(YEAR FROM COALESCE(start_date, created_at)) = ?', año) if año

    # ── 1. PÉRDIDAS por cepa ───────────────────────────────────────
    perdidas_por_genetica = lotes.group_by(&:genetica_id).filter_map do |gid, ls|
      g = ls.first&.genetica
      next unless g

      con_datos = ls.select { |l| l.plants_count.present? && l.plants_count > 0 }
      next if con_datos.empty?

      mermas = con_datos.map do |l|
        cosechadas = l.plants_count_cosechadas || l.plants.where(state: 'cosechado').count
        descartadas = l.plants.where(state: 'descartada').count
        total = l.plants_count
        {
          lote_id:         l.id,
          lote_codigo:     l.codigo,
          total:           total,
          cosechadas:      cosechadas,
          descartadas:     descartadas,
          merma_pct:       total > 0 ? ((total - cosechadas).to_f / total * 100).round(1) : nil,
          descarte_pct:    total > 0 ? (descartadas.to_f / total * 100).round(1) : nil,
        }
      end

      merma_avg   = mermas.filter_map { |m| m[:merma_pct] }
      descarte_avg = mermas.filter_map { |m| m[:descarte_pct] }

      {
        genetica_id:      gid,
        nombre:           g.nombre,
        lotes_count:      ls.size,
        merma_promedio:   merma_avg.any? ? (merma_avg.sum / merma_avg.size).round(1) : nil,
        descarte_promedio: descarte_avg.any? ? (descarte_avg.sum / descarte_avg.size).round(1) : nil,
        por_lote:         mermas.sort_by { |m| m[:lote_codigo] },
      }
    end.sort_by { |r| [-(r[:merma_promedio] || 0)] }

    # ── 2. CICLOS — tiempo en cada fase por cepa ────────────────────
    # Usa lote_eventos para calcular días reales entre transiciones
    eventos_por_lote = LoteEvento
      .where(lote_id: lotes.map(&:id), tipo: 'cambio_estado')
      .order(:registrado_en)
      .group_by(&:lote_id)

    ciclos_por_lote = lotes.filter_map do |l|
      evs = eventos_por_lote[l.id] || []
      next if evs.empty? && l.start_date.nil?

      # El vegetativo arranca cuando la planta entra a maceta, no en el esqueje: en el domo emite
      # raíz, no crece. El enraizado se mide aparte (abajo): es su propia etapa, no parte del vege.
      # Fallback a start_date solo para los lotes viejos/heredados sin evento de vegetativo.
      ev_veg = evs.find { |e| e.estado_nuevo == 'vegetativo' }
      fase_inicio = {}
      fase_inicio['vegetativo'] = ev_veg&.registrado_en || l.start_date&.to_time

      evs.each do |ev|
        next unless ev.estado_nuevo.present?
        next if ev.estado_nuevo == 'vegetativo'   # ya resuelto arriba
        fase_inicio[ev.estado_nuevo] = ev.registrado_en
      end

      fases = %w[vegetativo floracion cosecha secado curado]
      dias = {}
      fases.each_with_index do |fase, idx|
        inicio = fase_inicio[fase]
        siguiente = fases[idx + 1]
        fin = siguiente ? fase_inicio[siguiente] : nil
        fin ||= Time.current if l.estado == fase
        dias[fase] = inicio && fin ? ((fin - inicio) / 86400.0).round(1) : nil
      end

      next if dias.values.all?(&:nil?)

      # ── Enraizado: etapa PREVIA al ciclo, no una sub-fase del vegetativo ──
      # Días desde el esqueje/semilla hasta que prendió. Es lo que delata un propagador con
      # problemas: si se muere una manta térmica, este número se estira antes de caer el prendimiento.
      # `vegetativo` (arriba) ya es el vegetativo puro, así que no hace falta desglosarlo.
      propagacion_dias = if ev_veg && l.start_date
        ((ev_veg.registrado_en - l.start_date.to_time) / 86400.0).round(1)
      end
      veg_puro_dias = dias['vegetativo']

      {
        lote_id:        l.id,
        lote_codigo:    l.codigo,
        genetica_id:    l.genetica_id,
        propagacion:    propagacion_dias,
        vegetativo_puro: veg_puro_dias,
        # De dónde vino la planta. Un esqueje y una semilla NO enraízan igual, así que los días
        # de enraizado sólo se leen bien sabiendo contra qué origen compararlos.
        origen:         l.origen,
        **dias,
      }
    end

    ciclos_por_genetica = ciclos_por_lote.group_by { |c| c[:genetica_id] }.filter_map do |gid, cs|
      g = lotes.find { |l| l.genetica_id == gid }&.genetica
      next unless g

      fases = %w[vegetativo floracion cosecha secado curado]
      promedios = fases.map do |fase|
        vals = cs.filter_map { |c| c[fase] }
        [fase, vals.any? ? (vals.sum / vals.size).round(1) : nil]
      end.to_h

      # Promedios de sub-fases de propagación (solo para lotes que pasaron por esa etapa)
      prop_vals = cs.filter_map { |c| c[:propagacion] }
      veg_puro_vals = cs.filter_map { |c| c[:vegetativo_puro] }

      # Mezcla de orígenes de los lotes promediados: "3 de semilla · 9 de esqueje". Sin esto,
      # un promedio de enraizado alto puede ser una genética lenta o simplemente que ese mes se
      # trabajó con esquejes, y no hay forma de distinguirlo.
      origenes = cs.filter_map { |c| c[:origen] }.tally

      {
        genetica_id:     gid,
        nombre:          g.nombre,
        lotes_con_datos: cs.size,
        # `propagacion` es el ENRAIZADO: etapa propia, no una sub-fase del vegetativo. Estaba
        # calculada pero la tabla no la mostraba, así que ese tiempo quedaba invisible.
        enraizado:       prop_vals.any? ? (prop_vals.sum / prop_vals.size).round(1) : nil,
        propagacion:     prop_vals.any? ? (prop_vals.sum / prop_vals.size).round(1) : nil,
        origenes:        origenes,
        origen_label:    origenes.map { |o, n| "#{n} de #{o}" }.join(' · ').presence,
        vegetativo_puro: veg_puro_vals.any? ? (veg_puro_vals.sum / veg_puro_vals.size).round(1) : nil,
        **promedios,
      }
    end.sort_by { |r| r[:nombre] }

    # ── 3. COMPARATIVA — lotes finalizados por cepa ─────────────────
    lotes_finalizados = lotes.select { |l| l.rendimiento_real_g.present? }
    comparativa = lotes_finalizados.group_by(&:genetica_id).filter_map do |gid, ls|
      g = ls.first&.genetica
      next unless g && ls.size >= 2

      {
        genetica_id: gid,
        nombre:      g.nombre,
        lotes:       ls.map { |l|
          {
            id:                l.id,
            codigo:            l.codigo,
            rendimiento_g:     l.rendimiento_real_g&.to_f,
            objetivo_g:        l.rendimiento_objetivo_g&.to_f,
            plants_count:      l.plants_count,
            grow_type:         l.grow_type,
            light_type:        l.light_type,
            start_date:        l.start_date,
          }
        }.sort_by { |l| l[:rendimiento_g] || 0 }.reverse,
      }
    end.sort_by { |r| r[:nombre] }

    {
      perdidas:    perdidas_por_genetica,
      ciclos:      ciclos_por_genetica,
      comparativa: comparativa,
    }
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

  def pearson_r(xs, ys)
    n = xs.size
    return nil if n < 3

    mx = xs.sum.to_f / n
    my = ys.sum.to_f / n
    num = xs.zip(ys).sum { |x, y| (x - mx) * (y - my) }
    den = Math.sqrt(xs.sum { |x| (x - mx)**2 } * ys.sum { |y| (y - my)**2 })
    return nil if den < 1e-10
    (num / den).round(3)
  rescue
    nil
  end

  def regresion_lineal(xs, ys)
    n = xs.size
    return nil if n < 3

    r = pearson_r(xs, ys)
    return nil unless r

    mx = xs.sum.to_f / n
    my = ys.sum.to_f / n
    ss_xy = xs.zip(ys).sum { |x, y| (x - mx) * (y - my) }
    ss_xx = xs.sum { |x| (x - mx)**2 }
    return nil if ss_xx < 1e-10

    slope     = (ss_xy / ss_xx).round(4)
    intercept = (my - slope * mx).round(2)
    min_x     = xs.min.round(3)
    max_x     = xs.max.round(3)

    {
      r:,
      r_squared:   (r**2).round(3),
      slope:,
      intercept:,
      n:,
      x_min:       min_x,
      x_max:       max_x,
      y_at_xmin:   (slope * min_x + intercept).round(1),
      y_at_xmax:   (slope * max_x + intercept).round(1),
    }
  rescue
    nil
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

  # GET /api/analytics/costo_por_gramo_sede
  # $/gramo producido, agregado por SEDE. Cierra el círculo cultivo→plata:
  #   numerador   = Σ CostoLote.costo_total   (costo real del ciclo)
  #   denominador = Σ Lote.rendimiento_real_g  (gramos producidos, NO dispensados)
  # Un lote que costó plata y no rindió (pérdida) suma su costo con 0 gramos: es un costo
  # real de la producción de esa sede y así debe pesar en el $/g agregado.
  def costo_por_gramo_sede
    club = current_user.club
    cache_key = "analytics/costo_por_gramo_sede/#{club.id}/#{analytics_stamp(club)}"
    Rails.cache.delete(cache_key) if params[:bust]
    data = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      calcular_costo_por_gramo_sede(club)
    end
    render json: data
  end

  def calcular_costo_por_gramo_sede(club)
    # Solo lotes con costo calculado. La sede se resuelve con coalesce
    # (post-cosecha: lote.sede_id; en cultivo: sala.sede_id). Un lote con rendimiento real
    # ya pasó por cosecha y tiene sede_id directo; el fallback cubre lotes con costo cargado
    # que todavía están en cultivo (sin rendimiento aún).
    lotes = club.lotes.joins(:costo_lote).includes(:costo_lote, :sala, :genetica)

    sedes = club.sedes.index_by(&:id)
    acc = Hash.new { |h, k| h[k] = { costo_total: 0.0, gramos: 0.0, sin_rendimiento: 0, lotes: [] } }

    lotes.find_each do |lote|
      sede_id = lote.sede_id || lote.sala&.sede_id
      costo   = lote.costo_lote.costo_total.to_f
      gramos  = lote.rendimiento_real_g.to_f
      b = acc[sede_id]
      b[:costo_total]    += costo
      b[:gramos]         += gramos
      b[:sin_rendimiento] += 1 if gramos <= 0
      b[:lotes] << {
        id:                lote.id,
        codigo:            lote.codigo,
        genetica:          lote.genetica&.nombre,
        estado:            lote.estado,
        costo_total:       costo.round(2),
        gramos_producidos: gramos.round(2),
        costo_por_gramo:   gramos.positive? ? (costo / gramos).round(2) : nil,
      }
    end

    filas = acc.map do |sede_id, b|
      sede = sedes[sede_id]
      {
        sede_id:               sede_id,
        sede_nombre:           sede&.nombre || (sede_id ? "Sede ##{sede_id}" : 'Sin sede'),
        sede_tipo:             sede&.tipo,
        costo_total:           b[:costo_total].round(2),
        gramos_producidos:     b[:gramos].round(2),
        costo_por_gramo:       b[:gramos].positive? ? (b[:costo_total] / b[:gramos]).round(2) : nil,
        lotes_con_costo:       b[:lotes].size,
        lotes_sin_rendimiento: b[:sin_rendimiento],
        lotes:                 b[:lotes].sort_by { |l| -l[:costo_total] },
      }
    end.sort_by { |f| f[:sede_nombre] }

    total_costo  = filas.sum { |f| f[:costo_total] }
    total_gramos = filas.sum { |f| f[:gramos_producidos] }

    {
      sedes: filas,
      total: {
        costo_total:       total_costo.round(2),
        gramos_producidos: total_gramos.round(2),
        costo_por_gramo:   total_gramos.positive? ? (total_costo / total_gramos).round(2) : nil,
        lotes_con_costo:   filas.sum { |f| f[:lotes_con_costo] },
      },
    }
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

  private :calcular_rendimiento_genetica, :calcular_dispensador, :calcular_correlacion_ambiental,
          :agrupar_buckets, :calcular_produccion, :calcular_pl_lotes, :kpis_anuales,
          :pearson_r, :regresion_lineal, :calcular_contabilidad,
          :require_analytics_access!, :require_dispensador_access!
end
