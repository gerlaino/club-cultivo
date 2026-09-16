# El panel del dueño de la plataforma.
#
# Lo que había antes era un recuento: cuántas plantas, cuántos lotes, cuántos pacientes sumando
# todos los clubes. Nada de eso le sirve a quien vende el software —no es su cultivo— y encima
# tapaba lo único que sí importa: quién vence, quién necesita algo hoy y quién se está por ir.
# Los agregados se mudaron a Informes (SuperAdmin::InformesController), que es donde tienen
# sentido y donde son la semilla del benchmarking del sector.
#
# Todo se calcula sobre clubes REALES: un club demo tiene cientos de dispensaciones inventadas.
module SuperAdmin
  class Pulso
    # Cuánto silencio hace falta para sospechar que un club dejó de usar la app. Un club con
    # cultivo funcionando toca ALGO todas las semanas.
    DIAS_SIN_ACTIVIDAD = 21

    # Una sonda que no reporta en dos días está muerta, no ociosa.
    HORAS_IOT_MUDO = 48

    def initialize(hoy: Time.zone.today)
      @hoy    = hoy
      @clubes = Club.reales.activos.where(activo: true).to_a
    end

    def call
      {
        plata:         plata,
        agenda:        agenda,
        suscripciones: suscripciones,
        atencion:      atencion,
        sin_actividad: sin_actividad,
        salud:         salud,
        adopcion:      adopcion,
        totales:       { clubes_operando: @clubes.size },
      }
    end

    private

    attr_reader :hoy, :clubes

    # ── La plata ──────────────────────────────────────────────────────────
    #
    # Lo primero que mira quien vende: cuánto entra por mes, cuánto está vencido y sigue
    # operando (o sea, hay que cobrarlo) y cuánto vence este mes. Sale de `Precios` y de
    # `Club#factura?`: una prueba no suma, una suspendida tampoco.
    def plata
      facturables = clubes.select(&:factura?)
      vencidos    = facturables.select { |c| c.plan_vencido?(hoy) }
      este_mes    = facturables.select { |c| c.plan_activo_hasta.present? && c.plan_activo_hasta.between?(hoy, hoy.end_of_month) }

      {
        moneda:            Precios::MONEDA,
        mrr:               facturables.sum(&:precio_mensual),
        facturables:       facturables.size,
        vencido_ars:       vencidos.sum(&:precio_mensual),
        vencidos:          vencidos.size,
        vence_este_mes_ars: este_mes.sum(&:precio_mensual),
        vencen_este_mes:   este_mes.size,
        # Lo que hoy no entra pero podría: pruebas en curso, a precio de lista.
        en_prueba_ars:     clubes.select(&:plan_trial).sum(&:precio_mensual),
      }
    end

    # ── Lo que quedé en hacer ─────────────────────────────────────────────
    #
    # La próxima acción anotada en la ficha («llamar el 18/9»), cuando llega su día o ya pasó.
    # Es la mitad del CRM que faltaba: lo que uno mismo se prometió, en la misma cola que lo que
    # la app detecta sola. Una semana de anticipación, para poder ordenar la agenda.
    def agenda
      Club.reales.activos.where.not(proxima_accion_el: nil)
          .where('proxima_accion_el <= ?', hoy + 7)
          .order(:proxima_accion_el).map do |c|
        resumen(c).merge(accion: c.proxima_accion, el: c.proxima_accion_el, vencida: c.proxima_accion_el < hoy,
                         contacto: c.contacto_nombre)
      end
    end

    def suscripciones
      con_vencimiento = clubes.select { |c| c.plan_activo_hasta.present? }

      {
        vencidos: con_vencimiento.select { |c| c.plan_activo_hasta < hoy }.map { |c| resumen(c) },
        vencen_7:  entre(con_vencimiento, hoy, hoy + 7),
        vencen_30: entre(con_vencimiento, hoy + 8, hoy + 30),
        trials:    clubes.select(&:plan_trial).map { |c| resumen(c) },
        sin_vencimiento: clubes.count { |c| c.plan_activo_hasta.blank? },
        por_plan:  clubes.group_by { |c| PlanEnforcer.normalizar(c.plan) }.transform_values(&:size),
      }
    end

    def entre(lista, desde, hasta)
      lista.select { |c| c.plan_activo_hasta.between?(desde, hasta) }.map { |c| resumen(c) }
    end

    # ── Quién necesita algo mío hoy ───────────────────────────────────────
    #
    # Lo más caro del panel viejo: se prendían los módulos, se mostraba la demo y no funcionaba
    # ninguno, sin que nada dijera por qué. Ahora el club que tiene un módulo prendido y muerto
    # aparece acá, con qué le falta.
    def atencion
      pendientes = []

      clubes.each do |club|
        (Club::ADDONS.keys + Club::INCLUIDOS_EN_SUITE.keys).each do |modulo|
          next unless club.feature?(modulo)
          falta = club.falta_para_funcionar(modulo)
          next if falta.blank?

          pendientes << resumen(club).merge(
            modulo:       modulo,
            modulo_label: etiqueta_modulo(modulo),
            falta:        falta,
          )
        end
      end

      {
        modulos_a_medias: pendientes,
        sin_suites: clubes.reject { |c| Club::SUITES.keys.any? { |s| c.suite?(s) } }.map { |c| resumen(c) },
        # Con el motivo, para que la cola diga la acción que corresponde. Las archivadas ya no
        # son un pendiente.
        suspendidos: Club.reales.activos.where(activo: false, archivada_at: nil).map { |c|
          resumen(c).merge(motivo: c.suspension_motivo, motivo_label: Club::MOTIVOS_SUSPENSION[c.suspension_motivo],
                           suspendida_at: c.suspendida_at)
        },
      }
    end

    def etiqueta_modulo(clave)
      Club::ADDONS.dig(clave, :label) || Club::INCLUIDOS_META.dig(clave, :label) || clave.humanize
    end

    # ── Quién se está por ir ──────────────────────────────────────────────
    #
    # El churn que importa es el que todavía no pasó. Se mide por cuándo ENTRÓ alguien del
    # equipo por última vez (`users.visto_at`, desde sep-2026): antes se miraba la última
    # dispensa y el último lote creado, y una organización sólo-Cultivo —que abre un lote cada
    # dos meses— aparecía en silencio trabajando a diario. Para las organizaciones sin marca
    # todavía (el deploy es reciente) se cae al rastro que deja escribir (`Auditoria`) y, en
    # último término, a la dispensa y el lote de antes.
    def sin_actividad
      corte = hoy - DIAS_SIN_ACTIVIDAD
      ids   = clubes.map(&:id)
      return [] if ids.empty?

      ultima = ultima_actividad_por_club(ids)

      clubes.filter_map do |club|
        fecha = ultima[club.id]
        next if fecha.present? && fecha >= corte

        resumen(club).merge(
          ultima_actividad: fecha,
          dias_en_silencio: fecha ? (hoy - fecha).to_i : nil,
        )
      end
    end

    # Fecha de la última señal de vida de cada organización, por id. La consulta es una por
    # fuente, no una por organización.
    def ultima_actividad_por_club(ids)
      visto     = User.del_equipo.where(club_id: ids).group(:club_id).maximum(:visto_at)
      escrito   = ActsAsTenant.without_tenant { Auditoria.where(club_id: ids).group(:club_id).maximum(:created_at) }
      dispensa  = Dispensacion.no_canceladas.joins(:paciente)
                              .where(pacientes: { club_id: ids })
                              .group('pacientes.club_id').maximum(:fecha_dispensacion)
      lote      = Lote.where(club_id: ids).group(:club_id).maximum(:created_at)

      ids.to_h do |id|
        marcas = [visto[id]&.to_date, escrito[id]&.to_date, dispensa[id], lote[id]&.to_date].compact
        [id, marcas.max]
      end
    end

    # ── Salud de la plataforma ────────────────────────────────────────────
    #
    # Lo que hoy se descubría corriendo un rake a mano (`sidekiq:health`, 79 días sin worker
    # que nadie vio) o entrando al bucket: el último backup, y qué cron no corrió cuando tenía
    # que correr.
    def salud
      { iot_mudo: iot_mudo, sidekiq: sidekiq, backup: Backups::Ultimo.call, cron: cron }
    end

    # Cada job programado con su última corrida. `atrasado` cuando pasó más del doble de su
    # período sin encolarse: un cron que no corre no avisa, y este panel es el único lugar
    # donde se puede ver.
    def cron
      require 'sidekiq/cron/job'
      Sidekiq::Cron::Job.all.map do |j|
        ultima   = j.last_enqueue_time
        periodo  = periodo_de(j.cron)
        atrasado = periodo.present? && (ultima.nil? || ultima < Time.current - (periodo * 2))
        { nombre: j.name, cron: j.cron, descripcion: j.description, ultima: ultima, atrasado: atrasado }
      end.sort_by { |c| [c[:atrasado] ? 0 : 1, c[:nombre]] }
    rescue StandardError => e
      Rails.logger.warn("[Pulso] cron no disponible: #{e.class} #{e.message}")
      []
    end

    # Cuánto tarda en volver a correr, a partir del cron. Con lo justo para los que hay: por
    # minutos, por hora, por día, por semana. Lo anual (los informes semestrales) no se vigila.
    def periodo_de(cron)
      m, h, dom, mon, dow = cron.to_s.split
      return nil if mon != '*' || dom != '*'
      return 1.week if dow != '*'
      return 1.day  if h != '*'
      return 1.hour if m != '*' && !m.start_with?('*/')
      return m.delete_prefix('*/').to_i.minutes if m.start_with?('*/')

      nil
    end

    # Un club con el IoT contratado y las sondas calladas está pagando por nada y no se entera.
    # Es el fallo silencioso que sólo se cazaba corriendo un rake a mano.
    def iot_mudo
      con_iot = clubes.select { |c| c.feature?(:iot) }
      return [] if con_iot.empty?

      ultimas = LecturaAmbiental.where(club_id: con_iot.map(&:id))
                                .group(:club_id).maximum(:medido_at)

      con_iot.filter_map do |club|
        ultima = ultimas[club.id]
        next if ultima.present? && ultima > HORAS_IOT_MUDO.hours.ago

        resumen(club).merge(ultima_lectura: ultima)
      end
    end

    def sidekiq
      require 'sidekiq/api'
      stats = Sidekiq::Stats.new
      {
        disponible: true,
        encolados:  stats.enqueued,
        fallidos:   stats.failed,
        muertos:    Sidekiq::DeadSet.new.size,
        workers:    Sidekiq::ProcessSet.new.size,
      }
    rescue StandardError => e
      # Sin Redis el panel no puede reventar: que no haya cola es un dato, no un error de la
      # página.
      Rails.logger.warn("[Pulso] Sidekiq no disponible: #{e.class} #{e.message}")
      { disponible: false, error: 'No se pudo consultar la cola de trabajos.' }
    end

    # ── Adopción ──────────────────────────────────────────────────────────
    #
    # Cuántos clubes lo TIENEN contra cuántos lo tienen ANDANDO. La diferencia entre esas dos
    # columnas es exactamente el trabajo pendiente, y dice qué vender y qué dejar de ofrecer.
    # Y la tercera columna, USADO en los últimos 30 días: «Delivery: 4 tienen · 4 andando» con
    # cero paquetes en un mes es un módulo que se va a dar de baja. Cada módulo tiene su propia
    # señal de uso; los que no tienen ninguna medible (WhatsApp, ARICCAME) van en nil.
    DIAS_USO = 30

    def adopcion
      uso = uso_por_modulo
      (Club::SUITES.keys + Club::ADDONS.keys).map do |clave|
        con  = clubes.select { |c| c.feature?(clave) || c.suite?(clave) }
        {
          clave:    clave,
          label:    Club::SUITES.dig(clave, :label) || Club::ADDONS.dig(clave, :label),
          suite:    Club::SUITES.key?(clave),
          tienen:   con.size,
          andando:  con.count { |c| c.falta_para_funcionar(clave).blank? },
          usado:    uso.key?(clave) ? con.count { |c| uso[clave].include?(c.id) } : nil,
        }
      end
    end

    # Qué organizaciones dejaron rastro de cada módulo en los últimos 30 días. Una consulta por
    # módulo, agrupada por club, nunca una por organización.
    def uso_por_modulo
      ids   = clubes.map(&:id)
      desde = DIAS_USO.days.ago
      return {} if ids.empty?

      ActsAsTenant.without_tenant do
        ia = IaLlamada.where(club_id: ids).where('created_at >= ?', desde)
        {
          'cultivo'             => LoteEvento.where(club_id: ids).where('created_at >= ?', desde).distinct.pluck(:club_id),
          'produccion_dispensa' => Dispensacion.no_canceladas.joins(:paciente).where(pacientes: { club_id: ids })
                                               .where('fecha_dispensacion >= ?', desde.to_date).distinct.pluck('pacientes.club_id'),
          'delivery'            => Dispensacion.joins(:paciente).where(pacientes: { club_id: ids }).where.not(estado_envio: nil)
                                               .where('dispensaciones.created_at >= ?', desde).distinct.pluck('pacientes.club_id'),
          'bar'                 => BarVenta.where(club_id: ids).where('created_at >= ?', desde).distinct.pluck(:club_id),
          'eventos'             => EventoBar.where(club_id: ids).where('created_at >= ?', desde).distinct.pluck(:club_id),
          'mailer'              => MailEnviado.where(club_id: ids).where('created_at >= ?', desde).distinct.pluck(:club_id),
          'vista_paciente'      => User.where(club_id: ids, role: 'paciente').where('visto_at >= ?', desde).distinct.pluck(:club_id),
          'iot'                 => LecturaAmbiental.where(club_id: ids).where('medido_at >= ?', desde).distinct.pluck(:club_id),
          'ia'                  => ia.where.not(funcion: 'chatbot').distinct.pluck(:club_id),
          'chatbot'             => ia.where(funcion: 'chatbot').distinct.pluck(:club_id),
        }
      end
    end

    def resumen(club)
      {
        id:                club.id,
        nombre:            club.name,
        plan:              PlanEnforcer.normalizar(club.plan),
        trial:             club.plan_trial,
        plan_activo_hasta: club.plan_activo_hasta,
        # Cada fila con su número: «vencido hace 9 días» sin «$120.000/mes» al lado no dice
        # cuánto importa.
        precio_mensual:    club.precio_mensual,
        ultimo_ingreso:    club.ultimo_ingreso,
      }
    end
  end
end
