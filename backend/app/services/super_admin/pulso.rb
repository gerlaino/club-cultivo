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
        suspendidos: Club.reales.activos.where(activo: false).map { |c| resumen(c) },
      }
    end

    def etiqueta_modulo(clave)
      Club::ADDONS.dig(clave, :label) || Club::INCLUIDOS_META.dig(clave, :label) || clave.humanize
    end

    # ── Quién se está por ir ──────────────────────────────────────────────
    #
    # El churn que importa es el que todavía no pasó. No hay tracking de logins (Devise
    # trackable está apagado), así que se mide por el rastro que deja operar: la última
    # dispensación y el último lote abierto.
    def sin_actividad
      corte = hoy - DIAS_SIN_ACTIVIDAD
      ids   = clubes.map(&:id)
      return [] if ids.empty?

      ultima_dispensa = Dispensacion.no_canceladas.joins(:paciente)
                                    .where(pacientes: { club_id: ids })
                                    .group('pacientes.club_id').maximum(:fecha_dispensacion)
      ultimo_lote     = Lote.where(club_id: ids).group(:club_id).maximum(:created_at)

      clubes.filter_map do |club|
        marcas = [ultima_dispensa[club.id], ultimo_lote[club.id]&.to_date].compact
        ultima = marcas.max
        next if ultima.present? && ultima >= corte

        resumen(club).merge(
          ultima_actividad: ultima,
          dias_en_silencio: ultima ? (hoy - ultima).to_i : nil,
        )
      end
    end

    # ── Salud de la plataforma ────────────────────────────────────────────
    def salud
      { iot_mudo: iot_mudo, sidekiq: sidekiq }
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
    def adopcion
      (Club::SUITES.keys + Club::ADDONS.keys).map do |clave|
        con  = clubes.select { |c| c.feature?(clave) || c.suite?(clave) }
        {
          clave:    clave,
          label:    Club::SUITES.dig(clave, :label) || Club::ADDONS.dig(clave, :label),
          suite:    Club::SUITES.key?(clave),
          tienen:   con.size,
          andando:  con.count { |c| c.falta_para_funcionar(clave).blank? },
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
      }
    end
  end
end
