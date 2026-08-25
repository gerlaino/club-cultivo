class PlanEnforcer
  # El plan dice CUÁNTO, nunca QUÉ. Qué módulos tiene una organización se decide aparte, en
  # `Club::SUITES` / `Club::ADDONS`: mezclar las dos cosas era lo que hacía que una organización
  # "federación" quedara sin límites y sin poder hacer nada.
  #
  # `nil` = sin límite.
  #
  # `lotes` NO se limita a propósito. El lote es una unidad de ORGANIZACIÓN, no de capacidad:
  # limitarlo empuja al club a meter todo en un lote gigante para no chocar el tope, y eso
  # rompe la trazabilidad, que es el activo del producto. Lo que mide la capacidad real del
  # cultivo son las plantas.
  #
  # `usuarios` tampoco es un número: pasó a ser UNO POR ROL en el plan Básico (ver
  # `usuarios_por_rol`). Un tope global no decía nada —"5 usuarios" no se puede vender ni
  # explicar— y dejaba dar de alta cinco cultivadores y ningún dispensador.
  PLANES = {
    'basico' => { label: 'Básico', sedes: 1,   salas: 3,   lotes: nil, plantas: 450, pacientes: 50,  usuarios: nil, usuarios_por_rol: 1   },
    'total'  => { label: 'Total',  sedes: nil, salas: nil, lotes: nil, plantas: nil, pacientes: nil, usuarios: nil, usuarios_por_rol: nil },
  }.freeze

  PLAN_POR_DEFECTO = 'basico'.freeze

  # Los cuatro planes viejos, mapeados a los dos nuevos. La migración de datos reescribe la
  # columna, pero una organización con el valor viejo (una copia vieja, un seed) no puede quedar sin
  # límites por accidente: cae al que le corresponde en vez de a `PLANES[nil]`.
  PLANES_LEGACY = {
    'semilla'    => 'basico',
    'brote'      => 'basico',
    'cosecha'    => 'total',
    'federacion' => 'total',
  }.freeze

  # Qué se limita, en el orden en que se le muestra al super admin.
  RECURSOS = %i[sedes salas lotes plantas pacientes usuarios].freeze

  # A qué suite le importa cada tope. Sirve para no nombrarle salas y plantas a una organización
  # que no compró Cultivo: el alta elige los módulos ANTES que el plan, así que se puede mostrar
  # sólo lo que aplica. `nil` = le importa a cualquiera.
  RECURSO_SUITE = {
    sedes:     nil,
    salas:     'cultivo',
    lotes:     'cultivo',
    plantas:   'cultivo',
    pacientes: 'produccion_dispensa',
    usuarios:  nil,
  }.freeze

  # Normaliza cualquier valor guardado en `clubs.plan` a uno de los dos planes vigentes.
  def self.normalizar(plan)
    p = plan.to_s
    return p if PLANES.key?(p)
    PLANES_LEGACY[p] || PLAN_POR_DEFECTO
  end

  def initialize(club)
    @club   = club
    @plan   = self.class.normalizar(club.plan)
    @limite = PLANES[@plan]
  end

  def puede_crear_sede?
    return true if @limite[:sedes].nil?
    sedes_vigentes < @limite[:sedes]
  end

  # Sin este límite, una organización de una sola sede podía abrir salas sin techo: el plan medía el
  # continente y no el contenido.
  #
  # Cuenta las salas que EXISTEN, no las que están en uso: una sala en mantenimiento sigue
  # siendo de la organización y vuelve mañana. Contar sólo `activas` habría dejado abrir salas sin techo
  # poniéndolas todas en mantenimiento. Sólo la sala cerrada —dada de baja— libera lugar.
  def puede_crear_sala?
    return true if @limite[:salas].nil?
    salas_vigentes < @limite[:salas]
  end

  def puede_crear_lote?
    return true if @limite[:lotes].nil?
    @club.lotes.count < @limite[:lotes]
  end

  def puede_crear_planta?
    return true if @limite[:plantas].nil?
    Plant.joins(:lote).where(lotes: { club_id: @club.id }).count < @limite[:plantas]
  end

  def puede_crear_planta_bulk?(cantidad)
    return true if @limite[:plantas].nil?
    actuales = Plant.joins(:lote).where(lotes: { club_id: @club.id }).count
    actuales + cantidad <= @limite[:plantas]
  end

  def puede_crear_paciente?
    return true if @limite[:pacientes].nil?
    @club.pacientes.count < @limite[:pacientes]
  end

  # El cupo de usuarios es POR ROL, no un número global.
  #
  # `del_equipo`: el cupo es del EQUIPO. Los pacientes tienen cuenta para su portal y ya
  # gastan su propio límite (`pacientes`); contándolos acá se cobraban dos veces y un club
  # Básico se quedaba sin poder dar de alta empleados al quinto paciente con portal.
  #
  # En Básico va uno de cada rol: un cultivador, un dispensador, un médico. En Total, los que
  # necesite. Qué roles puede tener depende de los módulos contratados y eso lo decide
  # `Club#roles_para_alta`, que es otra pregunta: acá sólo se cuenta CUÁNTOS de ese rol.
  def puede_crear_usuario?(rol = nil)
    tope = @limite[:usuarios_por_rol]
    return true if tope.nil?
    # Sin rol no hay nada que contar. Que el rol sea válido lo valida el controller, que además
    # es el único que sabe si se puede asignar en esta organización.
    return true if rol.blank?
    return true if ROLES_SIN_TOPE.include?(rol.to_s)

    usuarios_de_rol(rol) < tope
  end

  # El admin queda FUERA del cupo por rol. No es un puesto de trabajo: es quien contrata, y son
  # dos socios más veces de las que es uno solo. Con tope de uno, un club de dos dueños no puede
  # darle acceso al segundo, y el día que el único admin se va hay que meter mano en la base
  # para devolverle el control a alguien — un tope que sólo se puede levantar desde adentro no
  # es un tope, es un incidente.
  ROLES_SIN_TOPE = %w[admin].freeze

  def usuarios_de_rol(rol) = @club.users.del_equipo.where(role: rol.to_s).count

  def usuarios_por_rol = @limite[:usuarios_por_rol]

  def info
    {
      plan:         @plan,
      label:        @limite[:label],
      trial:        @club.plan_trial,
      activo_hasta: @club.plan_activo_hasta,
      limites:      RECURSOS.to_h { |r| [r, @limite[r]] },
      # Aparte de los topes numéricos: el de usuarios no es un número, es "uno de cada rol".
      # Va suelto para que la pantalla lo pueda decir con palabras en vez de con una barra.
      usuarios_por_rol: @limite[:usuarios_por_rol],
      uso:          uso,
    }
  end

  def salas_vigentes = @club.salas.where.not(state: 'cerrada').count

  # Cuenta las sedes que EXISTEN, no las que están en uso — el mismo criterio que las salas, que
  # ya lo tenía. Con `activas` alcanzaba con desactivar la sede para liberar el cupo y crear
  # otra: una organización del plan Básico podía tener las sedes que quisiera creando, apagando
  # y volviendo a prender. Sólo borrarla libera lugar.
  def sedes_vigentes = @club.sedes.count

  def uso
    {
      sedes:     sedes_vigentes,
      salas:     salas_vigentes,
      lotes:     @club.lotes.count,
      plantas:   Plant.joins(:lote).where(lotes: { club_id: @club.id }).count,
      pacientes: @club.pacientes.count,
      usuarios:  @club.users.del_equipo.count,
    }
  end

  # El mensaje que ve quien se choca contra el tope. Tiene que decir tres cosas —qué plan
  # tenés, cuál es el tope y qué hacer— porque el usuario que lo lee no eligió el plan y no
  # tiene forma de averiguarlo desde donde está parado. "Límite del plan alcanzado" a secas
  # deja a alguien mirando un formulario que no guarda, sin saber si es un error o una regla.
  def self.error_limite(recurso, limite, plan: nil)
    plan_txt = plan.present? ? "El plan #{plan}" : 'Tu plan'
    msg = if limite
            "#{plan_txt} permite hasta #{limite} #{recurso}, y la organización ya llegó a ese número. " \
            'Para dar de alta más, hay que ampliar el plan: escribinos y lo cambiamos.'
          else
            "#{plan_txt} no incluye #{recurso}. Escribinos y lo habilitamos."
          end
    { error: 'limite_plan', errors: [msg], mensaje: msg, recurso: recurso.to_s, limite: limite,
      plan: plan, upgrade: true }
  end

  # El tope de usuarios no es un número, así que su mensaje tampoco puede serlo: "permite hasta
  # 1 usuarios" no se entiende. Tiene que nombrar el ROL, que es lo que la persona estaba
  # tratando de dar de alta, y decir la salida.
  def self.error_limite_rol(rol, plan: nil, tope: 1)
    label    = Club::ROLES_META.dig(rol.to_s, :label) || rol.to_s
    plan_txt = plan.present? ? "El plan #{plan}" : 'Tu plan'
    msg = "#{plan_txt} incluye #{tope == 1 ? 'un' : tope} #{label.downcase}#{tope == 1 ? '' : 's'} " \
          'y la organización ya lo tiene. Para sumar otro hay que ampliar el plan: escribinos y lo cambiamos.'
    { error: 'limite_plan', errors: [msg], mensaje: msg, recurso: 'usuarios', rol: rol.to_s,
      limite: tope, plan: plan, upgrade: true }
  end
end
