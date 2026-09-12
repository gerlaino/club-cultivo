module Informes
  # LO QUE EL REPROCANN LE DICE AL ADMIN, además de la nómina que se presenta:
  #
  #   · Las ENTREGAS a esta población en el período —por línea y por unidad, como Dispensaciones—
  #     y cuántas fueron a alguien SIN REPROCANN vigente ese día. Se juzgaba contra la categoría
  #     de HOY: un paciente en regla en marzo que venció en agosto figuraba como «entregado sin
  #     REPROCANN» para todo el año.
  #   · Los PENDIENTES con nombre: a quién llamar porque vence, quién ya venció (y si sigue
  #     retirando), quién no tiene seguimiento médico. Cumplimiento era esto mismo sin nombres,
  #     y con un número no se hace nada.
  class Reprocann
    LISTA_PANTALLA = 200

    def initialize(club:, desde:, hasta:)
      @club  = club
      @desde = desde
      @hasta = hasta
    end

    def activos = Paciente.for_club(@club.id).where(es_paciente: true)

    # ── Entregas del período ─────────────────────────────────────────────────

    def dispensaciones
      pacs = activos.pluck(:id, :reprocann_numero, :reprocann_vencimiento, :reprocann_estado)
                    .to_h { |id, n, v, e| [id, { numero: n, vencimiento: v, estado: e }] }
      return { total: 0, por_unidad: [], pacientes_atendidos: 0, sin_reprocann_vigente: 0, entregas_sin_vigente: 0 } if pacs.empty?

      disps = Dispensacion.no_canceladas.where(paciente_id: pacs.keys)
                          .where(fecha_dispensacion: @desde..@hasta)
                          .includes(items: :stock).to_a
      lineas = disps.flat_map { |d| d.items.any? ? d.items.map { |it| [it.stock&.unidad.presence || 'g', it.cantidad.to_d] } : [['g', d.cantidad.to_d]] }
      # Sin vigente EL DÍA DE LA ENTREGA: sin número, o vencido a esa fecha.
      sin_vigente = disps.select { |d| !vigente_el?(pacs[d.paciente_id], d.fecha_dispensacion) }
      {
        total:                 disps.size,
        por_unidad:            lineas.group_by(&:first).map { |u, ls| { unidad: u, cantidad: ls.sum(&:last).round(2).to_f } },
        pacientes_atendidos:   disps.map(&:paciente_id).uniq.size,
        sin_reprocann_vigente: sin_vigente.map(&:paciente_id).uniq.size,
        entregas_sin_vigente:  sin_vigente.size,
      }
    end

    def vigente_el?(p, fecha)
      return false if p.nil? || p[:numero].blank?
      return false if p[:estado].to_s == 'pendiente'
      return true  if p[:vencimiento].blank?

      p[:vencimiento] >= fecha
    end

    # ── Pendientes, con nombre ───────────────────────────────────────────────

    # Ordenados por urgencia: primero quien venció y retiró en el período, después los vencidos,
    # los que vencen en 30 días, los que están en trámite, y sin seguimiento al final.
    URGENCIA = { 'vencido_retiro' => 0, 'vencido' => 1, 'por_vencer' => 2, 'pendiente' => 3, 'sin_seguimiento' => 4 }.freeze

    def pendientes
      hoy = Time.zone.today
      ultimas = Dispensacion.no_canceladas.where(paciente_id: activos.select(:id))
                            .group(:paciente_id).maximum(:fecha_dispensacion)
      retiraron = Dispensacion.no_canceladas.where(paciente_id: activos.select(:id))
                              .where(fecha_dispensacion: @desde..@hasta).distinct.pluck(:paciente_id).to_set

      filas = activos.flat_map do |p|
        cat = p.reprocann_categoria
        base = { paciente_id: p.id, paciente: p.nombre_completo, dni: p.dni_normalizado.to_s,
                 dni_ultimos_3: p.dni_normalizado.to_s.last(3), vencimiento: p.reprocann_vencimiento,
                 dias: (p.reprocann_vencimiento && (p.reprocann_vencimiento - hoy).to_i),
                 ultima_entrega: ultimas[p.id] }
        out = []
        case cat
        when 'vencido'    then out << base.merge(pendiente: retiraron.include?(p.id) ? 'vencido_retiro' : 'vencido')
        when 'por_vencer' then out << base.merge(pendiente: 'por_vencer')
        when 'pendiente'  then out << base.merge(pendiente: 'pendiente')
        end
        out << base.merge(pendiente: 'sin_seguimiento') unless p.con_seguimiento_medico
        out
      end
      filas.sort_by { |f| [URGENCIA[f[:pendiente]], f[:dias] || 0, f[:paciente].to_s] }
    end

    def resumen_pendientes(filas)
      filas.group_by { |f| f[:pendiente] }.transform_values(&:size)
    end
  end
end
