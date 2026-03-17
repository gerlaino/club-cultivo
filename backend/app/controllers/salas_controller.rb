# backend/app/controllers/salas_controller.rb
class SalasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_sala, only: [:show, :update, :destroy]

  def index
    salas = current_user.club.salas
                        .includes(:sede, :lotes, :created_by)
                        .order(:nombre)
    render json: salas.map { |s| serialize_sala(s) }
  end

  def show
    render json: serialize_sala_detail(@sala)
  end

  def create
    sala = current_user.club.salas.build(sala_params)
    sala.created_by = current_user

    # Validar capacidad del plan
    enforcer = PlanEnforcer.new(current_user.club)
    unless enforcer.puede_crear_lote? # reutilizamos lotes como proxy de salas
      # No bloqueamos la creación de salas por plan, solo lotes y plantas
    end

    if sala.save
      render json: serialize_sala(sala), status: :created
    else
      render json: { errors: sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @sala.update(sala_params)
      render json: serialize_sala_detail(@sala)
    else
      render json: { errors: @sala.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @sala.lotes.any?
      return render json: { error: 'No se puede eliminar una sala con lotes activos' },
                    status: :unprocessable_entity
    end
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
      :nombre, :state, :kind, :notes, :pots_count, :plants_max, :sede_id
    )
  end

  def serialize_sala(s)
    {
      id:                   s.id,
      nombre:               s.nombre,
      state:                s.state,
      kind:                 s.kind,
      notes:                s.notes,
      pots_count:           s.pots_count,
      plants_max:           s.plants_max,
      plantas_totales:      s.plantas_totales,
      capacidad_disponible: s.capacidad_disponible,
      porcentaje_ocupacion: s.porcentaje_ocupacion,
      lotes_count:          s.lotes.count,
      sede: s.sede ? { id: s.sede.id, nombre: s.sede.nombre, tipo: s.sede.tipo } : nil,
      created_by:           s.created_by_name,
      updated_at:           s.updated_at,
    }
  end

  def serialize_sala_detail(s)
    serialize_sala(s).merge(
      lotes: s.lotes.order(created_at: :desc).map { |l|
        { id: l.id, codigo: l.codigo, estado: l.estado, plants_count: l.plants_count }
      }
    )
  end
end
