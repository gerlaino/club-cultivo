module Planes
  # LA cuenta de fechas de un plan aplicado: qué tarea va qué día y a quién. Es una sola para las
  # tres puertas —aplicar desde el lote, aplicar desde la pantalla de planes y publicar un plan con
  # fechas—, que hasta el 7-oct-2026 calculaban cada una a su manera. La del lote no entendía el
  # «Semana 2 · Día 3» de una plantilla: con una plantilla fallaba, y con un plan común toda tarea
  # sin fecha fija caía el día que empezó el lote y aparecía vencida.
  #
  # No crea nada: sólo dice las ocurrencias. Las crea `Planes::Materializar`, de a poco.
  #
  # Cómo se fecha cada tarea del plan:
  #   - Se repite ciertos días de la semana (`dias_semana`) → cada uno de esos días, entre el inicio
  #     y el fin.
  #   - Tiene fecha fija (`fecha_especifica`) → esa fecha, corrida lo que se corrió el inicio.
  #   - Tiene «Semana X · Día Y» (`dia_relativo`) → el inicio + esos días.
  #   - Nada de lo anterior → el día de inicio.
  class Calendario
    DIAS_A_WDAY = { 'lun' => 1, 'mar' => 2, 'mie' => 3, 'jue' => 4, 'vie' => 5, 'sab' => 6, 'dom' => 0 }.freeze

    Ocurrencia = Struct.new(:plan_tarea, :fecha, :asignada, keyword_init: true)

    attr_reader :omitidas

    # `corte`: sólo las tareas del plan que existían a ese momento. Lo que se le agrega a una
    # plantilla DESPUÉS de aplicarla no aparece en los lotes que ya la tenían: no cambia un plan
    # que alguien ya está siguiendo.
    def initialize(plan:, fecha_inicio:, objetivo: nil, corte: nil)
      @plan         = plan
      @fecha_inicio = fecha_inicio
      @objetivo     = objetivo
      @corte        = corte
      @omitidas     = []
    end

    def ocurrencias
      @ocurrencias ||= calcular
    end

    def fin
      @fin ||= if @plan.fecha_fin && @plan.fecha_inicio
                 @plan.fecha_fin + offset
               else
                 # Una plantilla no tiene fechas: dura hasta su último «Semana X · Día Y» (al menos
                 # una semana, para que una que sólo se repite tenga dónde repetirse).
                 @fecha_inicio + [plan_tareas.filter_map(&:dia_relativo).max.to_i, 6].max
               end
    end

    private

    def offset
      @plan.fecha_inicio ? (@fecha_inicio - @plan.fecha_inicio).to_i.days : 0.days
    end

    def plan_tareas
      @plan_tareas ||= begin
        scope = @plan.plan_tareas.includes(:responsable)
        scope = scope.where('plan_tareas.created_at <= ?', @corte) if @corte
        scope.to_a
      end
    end

    def lote = @objetivo.is_a?(Lote) ? @objetivo : nil

    def calcular
      lista = []
      plan_tareas.each do |pt|
        fechas_de(pt).each do |fecha|
          asignados_de(pt).each do |usuario|
            oc = Ocurrencia.new(plan_tarea: pt, fecha: fecha, asignada: usuario)
            Tarea.aplica_a_lote?(pt.tipo, lote) ? lista << oc : @omitidas << oc
          end
        end
      end
      lista.sort_by { |o| [o.fecha, o.plan_tarea.id] }
    end

    def fechas_de(pt)
      if pt.es_recurrente? && pt.dias_semana.present?
        wdays = pt.dias_array.filter_map { |d| DIAS_A_WDAY[d] }
        (@fecha_inicio..fin).select { |f| wdays.include?(f.wday) }
      elsif pt.fecha_especifica.present?
        [pt.fecha_especifica + offset]
      elsif !pt.dia_relativo.nil?
        [@fecha_inicio + pt.dia_relativo.days]
      else
        [@fecha_inicio]
      end
    end

    # A quién: los del rol sugerido (una tarea para cada uno), o el responsable, o nadie. La misma
    # regla que tenía la pantalla de planes.
    def asignados_de(pt)
      if pt.rol_sugerido.present?
        roles = pt.rol_sugerido.split(',').map(&:strip).reject(&:blank?)
        usuarios = equipo.select { |u| roles.include?(u.role) }
        return usuarios if usuarios.any?
      end
      [pt.responsable]
    end

    def equipo
      @equipo ||= @plan.club.users.del_equipo.to_a
    end
  end
end
