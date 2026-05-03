class DispositivosController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_dispositivo, only: [:show, :update, :destroy, :regenerar_token]

  def index
    dispositivos = current_user.club.dispositivos
                               .includes(:sala)
                               .order(:nombre_amigable)
    render json: dispositivos.map { |d| serialize(d) }
  end

  def show
    render json: serialize(@dispositivo)
  end

  def create
    dispositivo = current_user.club.dispositivos.build(dispositivo_params)
    if dispositivo.save
      render json: serialize(dispositivo), status: :created
    else
      render json: { errors: dispositivo.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @dispositivo.update(dispositivo_params)
      render json: serialize(@dispositivo)
    else
      render json: { errors: @dispositivo.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @dispositivo.destroy
    head :no_content
  end

  def regenerar_token
    plain_token = @dispositivo.regenerar_token!
    render json: { token: plain_token, mensaje: 'Token regenerado. Guardalo ahora, no se mostrará de nuevo.' }
  end

  private

  def set_dispositivo
    @dispositivo = current_user.club.dispositivos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Dispositivo no encontrado' }, status: :not_found
  end

  def dispositivo_params
    params.require(:dispositivo).permit(:sala_id, :nombre_amigable, :tipo, :estado, :serial, :metadata)
  end

  def require_admin!
    render json: { error: 'Forbidden' }, status: :forbidden unless current_user.admin?
  end

  def serialize(d)
    {
      id:                           d.id,
      nombre_amigable:              d.nombre_amigable,
      tipo:                         d.tipo,
      estado:                       d.estado,
      serial:                       d.serial,
      sala_id:                      d.sala_id,
      sala_nombre:                  d.sala&.nombre,
      ultima_lectura_at:            d.ultima_lectura_at,
      token_pendiente_confirmacion: d.token_pendiente_confirmacion?,
      created_at:                   d.created_at,
    }
  end
end
