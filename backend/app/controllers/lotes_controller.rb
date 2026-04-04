class LotesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_agricultor
  before_action :set_lote, only: [:show, :update, :destroy]
  before_action :set_sala, only: [:index, :create], if: -> { params[:sala_id].present? }

  # GET /lotes o GET /salas/:sala_id/lotes
  def index
    lotes = current_user.club.lotes.includes(:sala, :genetica)
    lotes = lotes.where(sala_id: @sala.id) if @sala.present?

    if current_user.cultivador?
      salas_ids = current_user.salas_ids_asignadas
      return render json: [] if salas_ids.empty?
      lotes = lotes.where(sala_id: salas_ids)
    end

    lotes = lotes.order(created_at: :desc)
    render json: lotes.map { |l| serialize_lote(l) }
  end

  # GET /lotes/:id
  def show
    render json: serialize_lote(@lote, include_plants: true)
  end

  # POST /salas/:sala_id/lotes
  def create
    @lote = @sala.lotes.build(lote_params)
    @lote.club = current_user.club

    plantas_iniciales = lote_params[:plants_count].to_i
    if plantas_iniciales > 0 && @sala.plants_max.to_i > 0
      disponible = @sala.capacidad_disponible
      if plantas_iniciales > disponible
        return render json: {
          errors: ["La sala '#{@sala.nombre}' solo tiene capacidad para #{disponible} plantas más (máx: #{@sala.plants_max})"]
        }, status: :unprocessable_entity
      end
    end

    if @lote.save
      # Crear registros de plantas automáticamente
      if plantas_iniciales > 0
        state_inicial = estado_a_state(@lote.estado)
        plantas_iniciales.times do |i|
          numero = (i + 1).to_s.rjust(3, '0')
          @lote.plants.create!(
            nombre:    "#{@lote.codigo}-P#{numero}",
            state:     state_inicial,
            genetica:  @lote.genetica,
            )
        end
      end

      render json: serialize_lote(@lote, include_plants: true), status: :created
    else
      render json: { errors: @lote.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /lotes/:id
  def update
    if @lote.update(lote_params)
      render json: serialize_lote(@lote)
    else
      render json: { errors: @lote.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /lotes/:id
  def destroy
    @lote.destroy
    head :no_content
  end

  private

  def estado_a_state(estado)
    {
      'semilla'    => 'germinacion',
      'vegetativo' => 'vegetativo',
      'floracion'  => 'floracion',
      'cosecha'    => 'cosechado',
      'curado'     => 'cosechado',
      'finalizado' => 'cosechado',
    }[estado] || 'vegetativo'
  end

  def set_sala
    @sala = current_user.club.salas.find(params[:sala_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sala no encontrada' }, status: :not_found
  end

  def set_lote
    @lote = current_user.club.lotes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def lote_params
    params.require(:lote).permit(
      :codigo, :start_date, :estado, :plants_count, :strain, :notes,
      :grow_type, :light_type, :genetica_id
    )
  end

  def require_admin_or_agricultor
    unless current_user.admin? || current_user.agricultor? || current_user.cultivador?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def serialize_lote(lote, include_plants: false)
    result = {
      id:                lote.id,
      sala_id:           lote.sala_id,
      codigo:            lote.codigo,
      estado:            lote.estado,
      start_date:        lote.start_date,
      plants_count:      lote.plants_count,
      strain:            lote.strain,
      notes:             lote.notes,
      grow_type:         lote.grow_type,
      light_type:        lote.light_type,
      genetica_id:       lote.genetica_id,
      genetica:          lote.genetica ? { id: lote.genetica.id, nombre: lote.genetica.nombre, registrada_inase: lote.genetica.registrada_inase } : nil,
      dias_desde_inicio: lote.dias_desde_inicio,
      progreso_ciclo:    lote.progreso_ciclo,
      costo_por_gramo:   lote.costo_lote&.costo_por_gramo&.to_f,
      tiene_costo:       lote.costo_lote.present?,
      sala: {
        id:     lote.sala.id,
        nombre: lote.sala.nombre,
      },
      created_at: lote.created_at,
      updated_at: lote.updated_at,
    }

    if include_plants
      result[:plants] = lote.plants.order(:nombre).map { |p|
        { id: p.id, nombre: p.nombre, codigo_qr: p.codigo_qr, state: p.state }
      }
    end

    result
  end
end


