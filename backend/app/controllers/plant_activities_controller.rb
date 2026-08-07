class PlantActivitiesController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :set_plant
  skip_before_action :require_admin_o_cultivador, raise: false

  def index
    # La planta hereda el CONTEXTO que vivió dentro del lote: sus propias actividades (registro,
    # mediciones, trasplantes, descarte) + las lecturas de ambiente + las fases y actividades del
    # lote (riego, nutrición…). Lo que NO hereda son las notas/alertas administrativas del lote
    # (ej. "Planta X descartada"): eso es de otras plantas y se ve en la vista del lote.
    activities = @plant.activities.order(occurred_at: :desc).limit(50)
    registros  = @plant.lote.registros_ambientales
                       .order(registrado_en: :desc)
                       .limit(50)
    # Excluimos el trasplante a nivel lote: cada planta ya tiene su propio PlantActivity de
    # trasplante (evita el duplicado).
    eventos    = @plant.lote.lote_eventos
                       .where(tipo: %w[cambio_estado actividad])
                       .where.not("tipo = 'actividad' AND categoria = 'trasplante'")
                       .order(registrado_en: :desc)
                       .limit(60)

    merged = activities.map { |a| serialize(a) } +
             registros.map  { |r| serialize_registro(r) } +
             eventos.map    { |e| serialize_evento(e) }

    merged.sort_by! { |e| e[:occurred_at] || '' }.reverse!
    render json: merged.first(80)
  end

  def create
    activity = @plant.activities.build(
      activity_type: params.dig(:plant_activity, :activity_type),
      description:   params.dig(:plant_activity, :description),
      metadata:      params.dig(:plant_activity, :metadata)&.to_unsafe_h || {},
      user:          current_user,
      occurred_at:   Time.current
    )

    # Actualizar campos denormalizados en la planta
    if activity.activity_type == 'registro_planta' && activity.metadata.present?
      meta = activity.metadata
      @plant.altura_actual = meta['altura_cm']    if meta['altura_cm'].present?
      @plant.num_colas     = meta['num_colas']    if meta['num_colas'].present?
      @plant.estado_salud  = meta['estado_salud'] if meta['estado_salud'].present?
      @plant.color_hojas   = meta['color_hojas']  if meta['color_hojas'].present?
      @plant.save!
    end

    if activity.save
      render json: serialize(activity), status: :created
    else
      render json: { errors: activity.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    activity = @plant.activities.find(params[:id])
    activity.destroy
    head :no_content
  end

  private

  def set_plant
    @plant = Plant.joins(:lote)
                  .where(lotes: { club_id: current_user.club_id })
                  .find(params[:plant_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Planta no encontrada' }, status: :not_found
  end

  def serialize(a)
    {
      id:            a.id,
      activity_type: a.activity_type,
      description:   a.description,
      metadata:      a.metadata,
      occurred_at:   a.occurred_at,
      usuario:       a.user.nombre_completo,
      created_at:    a.created_at
    }
  end

  def serialize_registro(r)
    {
      id:            "ra_#{r.id}",
      activity_type: 'registro_ambiental_lote',
      description:   r.observaciones,
      metadata: {
        tareas_realizadas:    r.tareas_realizadas,
        fertilizacion:        r.fertilizacion,
        notas_fertilizacion:  r.notas_fertilizacion,
        temperatura:          r.temperatura,
        humedad:              r.humedad,
        ph:                   r.ph,
        ec:                   r.ec,
        co2:                  r.co2,
        ppfd:                 r.ppfd,
        estado_general:       r.estado_general,
        plagas_observadas:    r.plagas_observadas,
        fuente:               r.fuente,
      }.compact,
      occurred_at: r.registrado_en,
      usuario:     r.user&.nombre_completo || 'Sistema',
      created_at:  r.created_at,
      _heredado:   true,
    }
  end

  FASE_LABELS = {
    'semilla' => 'Enraizado', 'esqueje' => 'Enraizado', 'germinacion' => 'Enraizado',
    'vegetativo' => 'Vegetativo', 'floracion' => 'Floración', 'cosecha' => 'Cosecha',
    'secado' => 'Secado', 'curado' => 'Curado', 'finalizado' => 'Finalizado',
  }.freeze

  def serialize_evento(e)
    case e.tipo
    when 'cambio_estado'
      atype = 'lote_fase'
      desc  = "#{FASE_LABELS[e.estado_anterior] || e.estado_anterior} → #{FASE_LABELS[e.estado_nuevo] || e.estado_nuevo}".sub(/^ → /, '')
      meta  = {}
    when 'actividad'
      cat   = LoteEvento::CATEGORIA_META[e.categoria] || {}
      atype = 'lote_actividad'
      desc  = [[cat['emoji'], cat['label']].compact.join(' '), e.descripcion].reject(&:blank?).join(' · ')
      meta  = e.metadata || {}
    else # nota / alerta (no se listan hoy en la planta, pero se serializa por robustez)
      atype = e.tipo == 'alerta' ? 'lote_alerta' : 'lote_nota'
      desc  = e.descripcion
      meta  = {}
    end
    {
      id:            "le_#{e.id}",
      activity_type: atype,
      description:   desc,
      metadata:      meta,
      occurred_at:   e.registrado_en,
      usuario:       e.user&.nombre_completo || 'Sistema',
      created_at:    e.created_at,
      _heredado:     true,
    }
  end
end
