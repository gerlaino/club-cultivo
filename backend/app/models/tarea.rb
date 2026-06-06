class Tarea < ApplicationRecord
  # ── Asociaciones ──────────────────────────────────────────────
  belongs_to :club
  belongs_to :asignada_a, class_name: 'User', optional: true
  belongs_to :creada_por, class_name: 'User'
  belongs_to :sala,  optional: true
  belongs_to :lote,  optional: true
  belongs_to :plant, optional: true
  belongs_to :parent_tarea, class_name: 'Tarea', optional: true
  has_many   :tareas_hijas, class_name: 'Tarea', foreign_key: :parent_tarea_id, dependent: :nullify
  belongs_to :origen_plan,  class_name: 'PlanTrabajo', optional: true
  belongs_to :plan_tarea,   class_name: 'PlanTarea',   optional: true

  # ── Enums ──────────────────────────────────────────────────────
  TIPOS       = %w[riego poda medicion limpieza cosecha transplante inspeccion otro
                   nutricion defoliacion scrog_lst ajuste_luz revision_plagas].freeze
  ESTADOS     = %w[pendiente en_progreso completada cancelada].freeze

  # Mapeo de tareas_realizadas (RegistroAmbiental) a tipo de Tarea
  TAREAS_REALIZADAS_MAP = {
    'riego'           => 'riego',
    'nutricion'       => 'nutricion',
    'poda'            => 'poda',
    'defoliacion'     => 'defoliacion',
    'scrog_lst'       => 'scrog_lst',
    'revision_plagas' => 'revision_plagas',
    'limpieza_sala'   => 'limpieza',
    'ajuste_luz'      => 'ajuste_luz',
  }.freeze
  PRIORIDADES = %w[baja normal alta urgente].freeze
  FRECUENCIAS = %w[diaria semanal quincenal mensual].freeze

  validates :titulo,    presence: true, length: { maximum: 200 }
  validates :tipo,      inclusion: { in: TIPOS }
  validates :estado,    inclusion: { in: ESTADOS }
  validates :prioridad, inclusion: { in: PRIORIDADES }
  validates :frecuencia, inclusion: { in: FRECUENCIAS }, allow_nil: true
  validates :horas_estimadas, numericality: { greater_than: 0, allow_nil: true }
  validates :horas_reales,    numericality: { greater_than: 0, allow_nil: true }

  # Al completar, registrar fecha
  before_save :set_fecha_completada, if: :completando?

  after_create_commit :push_asignacion_nueva, if: -> { asignada_a.present? }

  # ── Scopes ────────────────────────────────────────────────────
  scope :del_club,         ->(club_id) { where(club_id: club_id) }
  scope :asignadas_a,      ->(user_id) { where(asignada_a_id: user_id) }
  scope :pendientes,       -> { where(estado: 'pendiente') }
  scope :en_progreso,      -> { where(estado: 'en_progreso') }
  scope :completadas,      -> { where(estado: 'completada') }
  scope :activas,          -> { where(estado: %w[pendiente en_progreso]) }
  scope :de_hoy,           -> { where(fecha_programada: Time.zone.today) }
  scope :vencidas,         -> { where('fecha_programada < ? AND estado NOT IN (?)', Time.zone.today, %w[completada cancelada]) }
  scope :proximas,         -> { where(fecha_programada: Time.zone.today..7.days.from_now) }
  scope :con_lote,         -> { where.not(lote_id: nil) }
  scope :horas_pendientes, -> { con_lote.completadas.where(horas_aplicadas_al_lote: false).where.not(horas_reales: nil) }
  scope :por_prioridad,    -> { order(Arel.sql("CASE prioridad WHEN 'urgente' THEN 1 WHEN 'alta' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END")) }
  scope :recientes,        -> { order(created_at: :desc) }

  # ── Helpers de estado ─────────────────────────────────────────
  def pendiente?   = estado == 'pendiente'
  def en_progreso? = estado == 'en_progreso'
  def completada?  = estado == 'completada'
  def cancelada?   = estado == 'cancelada'
  def activa?      = pendiente? || en_progreso?
  def vencida?     = fecha_programada&.past? && activa?

  # Horas reales disponibles para aplicar al lote
  def tiene_horas_para_lote?
    lote_id.present? && completada? && horas_reales.present? && horas_reales > 0 && !horas_aplicadas_al_lote
  end

  # Costo estimado de mano de obra para esta tarea
  # Se usa tarifa del club o valor por defecto
  def costo_mano_obra_estimado(tarifa_hora_ars = 1500.0)
    return nil unless horas_reales.present?
    (horas_reales * tarifa_hora_ars).round(2)
  end

  # ── Métodos de negocio ────────────────────────────────────────

  # Marcar como en progreso
  def iniciar!(user)
    raise "No se puede iniciar una tarea #{estado}" unless pendiente?
    update!(estado: 'en_progreso')
  end

  # Completar tarea
  def completar!(horas_reales:, notas: nil)
    raise "No se puede completar una tarea #{estado}" if completada? || cancelada?
    update!(
      estado: 'completada',
      horas_reales: horas_reales,
      notas_completado: notas,
      fecha_completada: Time.current
    )
  end

  # Marcar que las horas ya fueron aplicadas al lote
  def marcar_horas_aplicadas!
    update!(horas_aplicadas_al_lote: true)
  end

  # Cierra automáticamente tareas pendientes cuando se guarda un registro ambiental.
  # es_privilegiado: admin/supervisor pueden cerrar tareas de cualquier cultivador.
  # Devuelve array con títulos de las tareas cerradas.
  def self.cerrar_por_registro!(tareas_realizadas:, usuario:, es_privilegiado:, lote: nil, sala: nil)
    tipos = Array(tareas_realizadas).filter_map { |tr| TAREAS_REALIZADAS_MAP[tr] }.uniq
    return [] if tipos.empty?

    scope = activas.where(tipo: tipos)

    if lote
      scope = scope.where(lote_id: lote.id)
    elsif sala
      lote_ids = sala.lotes.where.not(estado: 'finalizado').pluck(:id)
      return [] if lote_ids.empty?
      scope = scope.where('sala_id = ? OR lote_id IN (?)', sala.id, lote_ids)
    else
      return []
    end

    scope = scope.where(asignada_a_id: usuario.id) unless es_privilegiado

    cerradas = []
    scope.find_each do |t|
      t.update!(estado: 'completada', notas_completado: 'Completada automáticamente por registro de voz')
      cerradas << t.titulo
    end
    cerradas
  end

  def en_serie? = parent_tarea_id.present? || tareas_hijas.exists?

  def generar_serie!
    return [] unless recurrente? && frecuencia.present? && fecha_programada.present?

    paso = { 'diaria' => 1, 'semanal' => 7, 'quincenal' => 14, 'mensual' => 30 }[frecuencia] * (intervalo || 1)
    max  = recurrencia_veces.present? ? recurrencia_veces.to_i - 1 : 51
    max  = [max, 51].min

    hijas = []
    1.upto(max) do |i|
      siguiente = fecha_programada + (i * paso).days
      break if recurrencia_hasta.present? && siguiente > recurrencia_hasta

      hijas << Tarea.create!(
        club_id:          club_id,
        titulo:           titulo,
        tipo:             tipo,
        descripcion:      descripcion,
        prioridad:        prioridad,
        asignada_a_id:    asignada_a_id,
        creada_por_id:    creada_por_id,
        sala_id:          sala_id,
        lote_id:          lote_id,
        horas_estimadas:  horas_estimadas,
        fecha_programada: siguiente,
        estado:           'pendiente',
        recurrente:       false,
        parent_tarea_id:  id,
      )
    end
    hijas
  end

  private

  def push_asignacion_nueva
    PushNotificationService.notify_user_async(
      asignada_a,
      title: "Nueva tarea asignada",
      body:  titulo,
      url:   '/m/cultivador/tareas'
    )
  end

  def completando?
    estado_changed? && estado == 'completada' && fecha_completada.nil?
  end

  def set_fecha_completada
    self.fecha_completada = Time.current
  end
end