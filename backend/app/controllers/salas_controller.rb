class SalasController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_agricultor
  before_action :set_sala, only: [:show, :update, :destroy]

  # GET /salas
  def index
    @salas = current_user.club.salas.includes(:lotes).order(created_at: :desc)
    render json: @salas.map { |s| serialize_sala(s) }
  end

  # GET /salas/:id
  def show
    render json: serialize_sala(@sala, include_lotes: true)
  end

  # POST /salas
  def create
    @sala = current_user.club.salas.build(sala_params)
    @sala.created_by = current_user

    if @sala.save
      render json: serialize_sala(@sala), status: :created
    else
      render json: { errors: @sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /salas/:id
  def update
    if @sala.update(sala_params)
      render json: serialize_sala(@sala)
    else
      render json: { errors: @sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /salas/:id
  def destroy
    @sala.destroy
    head :no_content
  end

  private

  def set_sala
    @sala = current_user.club.salas.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Sala no encontrada' }, status: :not_found
  end

  def sala_params
    params.require(:sala).permit(
      :nombre, :state, :pots_count, :notes,
      :kind, :camera_stream_url, :camera_snapshot_url
    )
  end

  def require_admin_or_agricultor
    unless current_user.admin? || current_user.agricultor?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def serialize_sala(sala, include_lotes: false)
    result = {
      id: sala.id,
      nombre: sala.nombre,
      state: sala.state,
      pots_count: sala.pots_count,
      notes: sala.notes,
      kind: sala.kind,
      camera_stream_url: sala.camera_stream_url,
      camera_snapshot_url: sala.camera_snapshot_url,
      plantas_totales: sala.plantas_totales,
      porcentaje_ocupacion: sala.porcentaje_ocupacion,
      created_by_name: sala.created_by_name,
      created_at: sala.created_at,
      updated_at: sala.updated_at
    }

    if include_lotes
      result[:lotes] = sala.lotes.map { |l| serialize_lote_simple(l) }
    end

    result
  end

  def serialize_lote_simple(lote)
    {
      id: lote.id,
      codigo: lote.codigo,
      estado: lote.estado,
      plants_count: lote.plants_count,
      strain: lote.strain
    }
  end
end