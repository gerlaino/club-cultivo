class TareasAutoService
  # Tareas sugeridas al entrar en cada estado de un lote.
  # Formato: { estado => [{ tipo:, titulo:, descripcion:, prioridad:, dias_offset: }] }
  # dias_offset: días desde hoy para programar la tarea (0 = hoy)
  SUGERENCIAS = {
    'vegetativo' => [
      { tipo: 'medicion',     titulo: 'Medir EC y pH del sustrato', prioridad: 'alta',   dias_offset: 0 },
      { tipo: 'riego',        titulo: 'Primer riego en vegetativo',  prioridad: 'normal', dias_offset: 0 },
      { tipo: 'inspeccion',   titulo: 'Inspección de plagas',        prioridad: 'normal', dias_offset: 3 },
    ],
    'floracion' => [
      { tipo: 'ajuste_luz',   titulo: 'Ajustar fotoperiodo a 12/12',    prioridad: 'alta',   dias_offset: 0 },
      { tipo: 'scrog_lst',    titulo: 'Revisar/ajustar SCROG o LST',    prioridad: 'normal', dias_offset: 1 },
      { tipo: 'defoliacion',  titulo: 'Defoliación de inicio de flor',  prioridad: 'normal', dias_offset: 7 },
      { tipo: 'medicion',     titulo: 'Medir VPD y ajustar si necesario', prioridad: 'alta', dias_offset: 0 },
      { tipo: 'revision_plagas', titulo: 'Inspección preventiva de plagas y hongos', prioridad: 'alta', dias_offset: 3 },
    ],
    'cosecha' => [
      { tipo: 'cosecha',      titulo: 'Cosechar lote — coordinar equipo', prioridad: 'urgente', dias_offset: 0 },
      { tipo: 'limpieza',     titulo: 'Limpiar y preparar sala post-cosecha', prioridad: 'normal', dias_offset: 1 },
    ],
    'secado' => [
      { tipo: 'medicion',     titulo: 'Control de temperatura y humedad en secado', prioridad: 'alta',   dias_offset: 0 },
      { tipo: 'inspeccion',   titulo: 'Inspección visual de secado (botritis)',     prioridad: 'normal', dias_offset: 3 },
    ],
    'curado' => [
      { tipo: 'medicion',     titulo: 'Control de humedad en frascos',    prioridad: 'normal', dias_offset: 1 },
      { tipo: 'inspeccion',   titulo: 'Burping — ventilación de frascos', prioridad: 'normal', dias_offset: 2 },
    ],
  }.freeze

  def initialize(lote:, estado_nuevo:, user:, club:)
    @lote        = lote
    @estado      = estado_nuevo
    @user        = user
    @club        = club
  end

  def call
    plantillas = SUGERENCIAS[@estado]
    return unless plantillas

    # Cultivador responsable del lote o quien disparó la transición
    asignado = @lote.sala&.responsable || @user

    plantillas.each do |t|
      Tarea.create!(
        club:              @club,
        creada_por:        @user,
        asignada_a:        asignado,
        lote:              @lote,
        sala:              @lote.sala,
        titulo:            t[:titulo],
        descripcion:       t[:descripcion],
        tipo:              t[:tipo],
        prioridad:         t[:prioridad],
        estado:            'pendiente',
        fecha_programada:  Time.zone.today + t[:dias_offset],
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[TareasAutoService] Error creando tareas para lote #{@lote.id}: #{e.message}")
  end
end
