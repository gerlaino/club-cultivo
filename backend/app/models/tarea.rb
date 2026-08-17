class Tarea < ApplicationRecord
  include Restorable
  # ── Asociaciones ──────────────────────────────────────────────
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :asignada_a, class_name: 'User', optional: true
  belongs_to :creada_por, class_name: 'User'
  belongs_to :sala,  optional: true
  belongs_to :lote,  optional: true
  belongs_to :plant, optional: true
  belongs_to :parent_tarea, class_name: 'Tarea', optional: true
  has_many   :tareas_hijas, class_name: 'Tarea', foreign_key: :parent_tarea_id, dependent: :nullify
  belongs_to :origen_plan,    class_name: 'PlanTrabajo',   optional: true
  belongs_to :plan_tarea,     class_name: 'PlanTarea',     optional: true
  belongs_to :aplicacion_plan, class_name: 'AplicacionPlan', optional: true

  # ── Enums ──────────────────────────────────────────────────────
  TIPOS       = %w[riego poda medicion limpieza cosecha trasplante inspeccion otro
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
  # Una tarea sin lote NI sala es de toda la organización — "limpieza general", sin lugar
  # asignado. No entraba en ninguna rama de `candidatas_por_registro`, así que decías "hice la
  # limpieza", el modelo lo entendía perfecto y la tarea igual quedaba abierta: no aparecía ni
  # para destildar. Ahora entra siempre como candidata, y la pantalla la marca para que se vea
  # que no es de esta sala antes de darla por hecha.
  SIN_UBICACION = '(tareas.lote_id IS NULL AND tareas.sala_id IS NULL)'.freeze

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
  # Pendientes reales "del día": vencidas + las de hoy (y sin fecha). NO incluye futuras.
  scope :pendientes_al_dia, -> { activas.where('fecha_programada <= ? OR fecha_programada IS NULL', Time.zone.today) }
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
  # Programada para después de hoy. Una tarea sin fecha NO es futura: es "cuando se pueda",
  # y esas se completan cualquier día.
  def programada_a_futuro? = fecha_programada.present? && fecha_programada > Time.zone.today

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

  # Las tareas que un registro por voz DARÍA por hechas. Devuelve candidatas: no cierra nada.
  #
  # Antes esto cerraba solo, en tanda y DESPUÉS de guardar: el cultivador decía "regué" y se
  # completaban todas las tareas de riego del lote o de la sala sin que llegara a ver cuáles,
  # enterándose por una línea de texto cuando ya estaba hecho. Con tres riegos pendientes se
  # cerraban los tres. Y para admin y supervisor cerraba además las de otra gente. Deshacerlo era
  # ir a Tareas y reabrirlas de a una.
  #
  # El matching sigue siendo determinístico —por tipo de tarea, no por criterio del modelo—: el
  # modelo sólo entiende que dijiste "regué", la lista la arma la base. Quién dictó elige cuáles
  # cierra, antes de guardar.
  #
  # es_privilegiado: admin/supervisor ven también las tareas de otra gente.
  def self.candidatas_por_registro(tareas_realizadas:, usuario:, es_privilegiado:, lote: nil, sala: nil)
    tipos = Array(tareas_realizadas).filter_map { |tr| TAREAS_REALIZADAS_MAP[tr] }.uniq
    return none if tipos.empty?

    scope = activas.where(tipo: tipos)

    if lote
      scope = scope.where("tareas.lote_id = ? OR #{SIN_UBICACION}", lote.id)
    elsif sala
      lote_ids = sala.lotes.where.not(estado: 'finalizado').pluck(:id)
      scope = scope.where(
        "tareas.sala_id = ? OR tareas.lote_id IN (?) OR #{SIN_UBICACION}", sala.id, lote_ids
      )
    else
      return none
    end

    es_privilegiado ? scope : scope.where(asignada_a_id: usuario.id)
  end

  # Cierra exactamente las que la persona confirmó en la pantalla de revisión. Nunca elige por su
  # cuenta.
  #
  # Los ids se vuelven a filtrar por organización y por permiso aunque vengan de `candidatas`: lo
  # que llega es un POST y por ahí puede venir cualquier id. La regla no puede vivir sólo en la
  # pantalla que armó la lista.
  def self.cerrar_confirmadas!(ids:, usuario:, es_privilegiado:, club:)
    ids = Array(ids).map(&:to_i).reject(&:zero?)
    return [] if ids.empty?

    scope = del_club(club.id).activas.where(id: ids)
    scope = scope.where(asignada_a_id: usuario.id) unless es_privilegiado

    scope.map do |t|
      t.update!(estado: 'completada', notas_completado: 'Completada por registro de voz')
      t.titulo
    end
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