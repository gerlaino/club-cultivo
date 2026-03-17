class PlanEnforcer
  PLANES = {
    'semilla'    => { label: 'Semilla',    sedes: 1,   lotes: 2,   plantas: 50,  pacientes: 30,  usuarios: 3  },
    'brote'      => { label: 'Brote',      sedes: 2,   lotes: 6,   plantas: 150, pacientes: 100, usuarios: 8  },
    'cosecha'    => { label: 'Cosecha',    sedes: 3,   lotes: nil, plantas: nil, pacientes: 250, usuarios: 20 },
    'federacion' => { label: 'Federacion', sedes: nil, lotes: nil, plantas: nil, pacientes: nil, usuarios: nil },
  }.freeze

  def initialize(club)
    @club   = club
    @plan   = club.plan || 'semilla'
    @limite = PLANES[@plan] || PLANES['semilla']
  end

  def puede_crear_sede?
    return true if @limite[:sedes].nil?
    @club.sedes.activas.count < @limite[:sedes]
  end

  def puede_crear_lote?
    return true if @limite[:lotes].nil?
    @club.lotes.count < @limite[:lotes]
  end

  def puede_crear_planta?
    return true if @limite[:plantas].nil?
    Plant.joins(:lote).where(lotes: { club_id: @club.id }).count < @limite[:plantas]
  end

  def puede_crear_paciente?
    return true if @limite[:pacientes].nil?
    @club.socios.count < @limite[:pacientes]
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
      limites: {
        sedes:     @limite[:sedes],
        lotes:     @limite[:lotes],
        plantas:   @limite[:plantas],
        pacientes: @limite[:pacientes],
        usuarios:  @limite[:usuarios],
      },
      uso: {
        sedes:     @club.sedes.activas.count,
        lotes:     @club.lotes.count,
        plantas:   Plant.joins(:lote).where(lotes: { club_id: @club.id }).count,
        pacientes: @club.socios.count,
        usuarios:  @club.users.count,
      },
    }
  end

  def self.error_limite(recurso, limite)
    { error: 'limite_plan', mensaje: "Tu plan no permite mas #{recurso}. Limite: #{limite || 'ilimitado'}", upgrade: true }
  end
end
