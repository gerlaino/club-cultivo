class DispensacionesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_medico_agricultor_or_admin, except: [:index, :show]
  before_action :set_socio, only: [:index, :create]
  before_action :set_dispensacion, only: [:show, :update, :destroy]

  # GET /socios/:socio_id/dispensaciones
  def index
    @dispensaciones = @socio.dispensaciones.includes(:user, :lote, :indicacion_medica).recientes

    cupo_disponible = Dispensacion.cupo_disponible(@socio.id)
    total_mes = Dispensacion.total_dispensado_mes(@socio.id)

    render json: {
      dispensaciones: @dispensaciones.map { |d| serialize_dispensacion(d) },
      cupo_mensual: Dispensacion::CUPO_MENSUAL_GRAMOS,
      total_dispensado_mes: total_mes.to_f.round(2),
      cupo_disponible: cupo_disponible.to_f.round(2)
    }
  end

  # GET /dispensaciones/:id
  def show
    render json: serialize_dispensacion(@dispensacion)
  end

  # POST /socios/:socio_id/dispensaciones
  def create
    @dispensacion = @socio.dispensaciones.build(dispensacion_params)
    @dispensacion.user = current_user

    if @dispensacion.save
      render json: serialize_dispensacion(@dispensacion), status: :created
    else
      render json: { errors: @dispensacion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /dispensaciones/:id
  def update
    if @dispensacion.update(dispensacion_params)
      render json: serialize_dispensacion(@dispensacion)
    else
      render json: { errors: @dispensacion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /dispensaciones/:id
  def destroy
    @dispensacion.destroy
    head :no_content
  end

  private

  def set_socio
    @socio = current_user.club.socios.find(params[:socio_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Socio no encontrado' }, status: :not_found
  end

  def set_dispensacion
    @dispensacion = Dispensacion.joins(:socio).where(socios: { club_id: current_user.club_id }).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Dispensación no encontrada' }, status: :not_found
  end

  def dispensacion_params
    params.require(:dispensacion).permit(
      :indicacion_medica_id,
      :lote_id,
      :cantidad_gramos,
      :tipo_producto,
      :observaciones,
      :fecha_dispensacion
    )
  end

  def require_medico_agricultor_or_admin
    unless current_user.admin? || current_user.medico? || current_user.agricultor?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def serialize_dispensacion(dispensacion)
    {
      id: dispensacion.id,
      socio_id: dispensacion.socio_id,
      socio_nombre: "#{dispensacion.socio.nombre} #{dispensacion.socio.apellido}",
      usuario: {
        id: dispensacion.user.id,
        nombre: dispensacion.user.first_name || dispensacion.user.email
      },
      indicacion_medica: dispensacion.indicacion_medica ? {
        id: dispensacion.indicacion_medica.id,
        patologia: dispensacion.indicacion_medica.patologia
      } : nil,
      lote: dispensacion.lote ? {
        id: dispensacion.lote.id,
        codigo: dispensacion.lote.codigo
      } : nil,
      cantidad_gramos: dispensacion.cantidad_gramos.to_f.round(2),
      tipo_producto: dispensacion.tipo_producto,
      observaciones: dispensacion.observaciones,
      fecha_dispensacion: dispensacion.fecha_dispensacion,
      created_at: dispensacion.created_at,
      updated_at: dispensacion.updated_at
    }
  end
end