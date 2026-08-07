module Medico
  class PacientesController < BaseController
    PER_PAGE_DEFAULT = 30
    # El tope es alto porque la turnera pide la lista entera para su selector de pacientes.
    PER_PAGE_MAX     = 500

    FILTROS = %w[todos activos proximos vencidos sin_rep].freeze

    # GET /api/medico/pacientes
    #
    # Paginado: antes devolvía TODOS los pacientes del club en un solo JSON, sin techo.
    #
    # El orden por defecto no es alfabético sino "de agenda": primero quien tiene turno con este
    # médico, después quien tiene una indicación por vencer, y recién al final el resto por
    # apellido. Un médico no navega el padrón del club, navega a quién tiene que ver.
    def index
      page   = [params[:pagina].to_i, 1].max
      limit  = (params[:limite].presence || PER_PAGE_DEFAULT).to_i.clamp(1, PER_PAGE_MAX)
      query  = params[:query].to_s.strip
      filtro = params[:filtro].presence_in(FILTROS) || 'todos'

      base  = club.pacientes.where(deleted_at: nil)
      base  = filtrar_por_texto(base, query) if query.present?
      scope = filtrar_por_estado(base, filtro)

      total = scope.count

      pacientes = scope
                  .joins(sql_proximo_turno)
                  .joins(sql_indicacion_por_vencer)
                  .select('pacientes.*, t.proximo AS proximo_turno_at, i.vence AS indicacion_vence_at')
                  .order(Arel.sql(<<~SQL))
                    t.proximo ASC NULLS LAST,
                    i.vence   ASC NULLS LAST,
                    pacientes.apellido ASC, pacientes.nombre ASC
                  SQL
                  .offset((page - 1) * limit)
                  .limit(limit)
                  .to_a

      render json: {
        data: pacientes.map { |p| serialize_paciente_resumen(p) },
        meta: { pagina: page, limite: limit, total: total, kpis: kpis(base) },
      }
    end

    private

    # Los contadores de la cabecera se cuentan sobre TODO lo que matchea la búsqueda, no sobre la
    # página: paginando, contar en el cliente daría "3 vencidos" cuando hay 40.
    def kpis(base)
      hoy = Time.zone.today

      {
        total:    base.count,
        activos:  base.where(es_paciente: true).count,
        proximos: base.where(reprocann_vencimiento: hoy..(hoy + 30)).count,
        vencidos: base.where(reprocann_vencimiento: ...hoy).count,
        sin_rep:  base.where(reprocann_vencimiento: nil).count,
      }
    end

    def filtrar_por_estado(scope, filtro)
      hoy = Time.zone.today

      case filtro
      when 'activos'  then scope.where(es_paciente: true)
      when 'proximos' then scope.where(reprocann_vencimiento: hoy..(hoy + 30))
      when 'vencidos' then scope.where(reprocann_vencimiento: ...hoy)
      when 'sin_rep'  then scope.where(reprocann_vencimiento: nil)
      else scope
      end
    end

    # El DNI va cifrado determinístico: admite igualdad exacta, no LIKE. Mismo criterio que
    # PacientesController#index, para que buscar signifique lo mismo en las dos pantallas.
    def filtrar_por_texto(scope, query)
      q        = "%#{query.downcase}%"
      by_name  = scope.where('lower(pacientes.nombre) LIKE :q OR lower(pacientes.apellido) LIKE :q', q: q)
      dni_term = query.gsub(/\D/, '')

      dni_term.present? ? by_name.or(scope.where(dni_normalizado: dni_term)) : by_name
    end

    def sql_proximo_turno
      sanitize_sql([<<~SQL, medico_id: current_user.id, ahora: Time.current])
        LEFT JOIN (
          SELECT paciente_id, MIN(fecha_hora) AS proximo
          FROM turnos
          WHERE medico_id = :medico_id
            AND fecha_hora >= :ahora
            AND estado IN ('programado', 'confirmado')
          GROUP BY paciente_id
        ) t ON t.paciente_id = pacientes.id
      SQL
    end

    def sql_indicacion_por_vencer
      sanitize_sql([<<~SQL, hoy: Time.zone.today])
        LEFT JOIN (
          SELECT paciente_id, MIN(fecha_vencimiento) AS vence
          FROM indicacion_medicas
          WHERE activa = TRUE
            AND fecha_vencimiento IS NOT NULL
            AND fecha_vencimiento >= :hoy
          GROUP BY paciente_id
        ) i ON i.paciente_id = pacientes.id
      SQL
    end

    def sanitize_sql(statement)
      ActiveRecord::Base.sanitize_sql_array(statement)
    end

    def serialize_paciente_resumen(p)
      hoy  = Time.zone.today
      venc = p.reprocann_vencimiento

      {
        id:                     p.id,
        nombre:                 p.nombre,
        apellido:               p.apellido,
        nombre_completo:        "#{p.nombre} #{p.apellido}",
        dni:                    p.dni,
        email:                  p.email,
        edad:                   edad(p.fecha_nacimiento, hoy),
        diagnostico_principal:  p.diagnostico_principal,
        reprocann_estado:       p.reprocann_estado,
        reprocann_vencimiento:  venc,
        dias_hasta_vencimiento: venc ? (venc - hoy).to_i : nil,
        con_seguimiento:        p.con_seguimiento_medico,
        es_paciente:            p.es_paciente,
        # Lo que pone al paciente arriba en la lista, para poder mostrarlo en la fila.
        proximo_turno_at:       p.try(:proximo_turno_at),
        indicacion_vence_at:    p.try(:indicacion_vence_at),
      }
    end

    def edad(fecha_nacimiento, hoy)
      return nil unless fecha_nacimiento

      hoy.year - fecha_nacimiento.year -
        (hoy < fecha_nacimiento + (hoy.year - fecha_nacimiento.year).years ? 1 : 0)
    end
  end
end
