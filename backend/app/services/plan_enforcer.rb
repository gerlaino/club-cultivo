class PlanEnforcer
  # El plan dice CUÁNTO, nunca QUÉ. Qué módulos tiene un club se decide aparte, en
  # `Club::SUITES` / `Club::ADDONS`: mezclar las dos cosas era lo que hacía que un club
  # "federación" quedara sin límites y sin poder hacer nada.
  #
  # `nil` = sin límite.
  PLANES = {
    'basico' => { label: 'Básico', sedes: 1,   salas: 3,   lotes: 4,   plantas: 200, pacientes: 80,  usuarios: 5   },
    'total'  => { label: 'Total',  sedes: nil, salas: nil, lotes: nil, plantas: nil, pacientes: nil, usuarios: nil },
  }.freeze

  PLAN_POR_DEFECTO = 'basico'.freeze

  # Los cuatro planes viejos, mapeados a los dos nuevos. La migración de datos reescribe la
  # columna, pero un club con el valor viejo (una copia vieja, un seed) no puede quedar sin
  # límites por accidente: cae al que le corresponde en vez de a `PLANES[nil]`.
  PLANES_LEGACY = {
    'semilla'    => 'basico',
    'brote'      => 'basico',
    'cosecha'    => 'total',
    'federacion' => 'total',
  }.freeze

  # Qué se limita, en el orden en que se le muestra al super admin.
  RECURSOS = %i[sedes salas lotes plantas pacientes usuarios].freeze

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
    @club.sedes.activas.count < @limite[:sedes]
  end

  # Sin este límite, un club de una sola sede podía abrir salas sin techo: el plan medía el
  # continente y no el contenido.
  #
  # Cuenta las salas que EXISTEN, no las que están en uso: una sala en mantenimiento sigue
  # siendo del club y vuelve mañana. Contar sólo `activas` habría dejado abrir salas sin techo
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

  def puede_crear_usuario?
    return true if @limite[:usuarios].nil?
    @club.users.count < @limite[:usuarios]
  end

  def info
    {
      plan:         @plan,
      label:        @limite[:label],
      trial:        @club.plan_trial,
      activo_hasta: @club.plan_activo_hasta,
      limites:      RECURSOS.to_h { |r| [r, @limite[r]] },
      uso:          uso,
    }
  end

  def salas_vigentes = @club.salas.where.not(state: 'cerrada').count

  def uso
    {
      sedes:     @club.sedes.activas.count,
      salas:     salas_vigentes,
      lotes:     @club.lotes.count,
      plantas:   Plant.joins(:lote).where(lotes: { club_id: @club.id }).count,
      pacientes: @club.pacientes.count,
      usuarios:  @club.users.count,
    }
  end

  # El mensaje que ve quien se choca contra el tope. Tiene que decir tres cosas —qué plan
  # tenés, cuál es el tope y qué hacer— porque el usuario que lo lee no eligió el plan y no
  # tiene forma de averiguarlo desde donde está parado. "Límite del plan alcanzado" a secas
  # deja a alguien mirando un formulario que no guarda, sin saber si es un error o una regla.
  def self.error_limite(recurso, limite, plan: nil)
    plan_txt = plan.present? ? "El plan #{plan}" : 'Tu plan'
    msg = if limite
            "#{plan_txt} permite hasta #{limite} #{recurso}, y el club ya llegó a ese número. " \
            'Para dar de alta más, hay que ampliar el plan: escribinos y lo cambiamos.'
          else
            "#{plan_txt} no incluye #{recurso}. Escribinos y lo habilitamos."
          end
    { error: 'limite_plan', errors: [msg], mensaje: msg, recurso: recurso.to_s, limite: limite,
      plan: plan, upgrade: true }
  end
end
