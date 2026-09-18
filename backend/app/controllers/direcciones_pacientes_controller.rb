# Las direcciones de entrega del paciente (solapa «Direcciones» de la ficha): listar, agregar,
# corregir, borrar y elegir la por defecto. El domicilio REPROCANN se edita con la ficha, no acá.
class DireccionesPacientesController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:produccion_dispensa) }
  before_action :check_role!
  before_action :set_paciente
  before_action :set_direccion, only: [:update, :destroy, :por_defecto]

  # GET /pacientes/:paciente_id/direcciones — el domicilio y las guardadas, con texto.
  def index
    render json: @paciente.direcciones
  end

  def create
    d = @paciente.direcciones_guardadas.build(direccion_params.merge(club: @paciente.club))
    if d.save
      render json: d.como_json, status: :created
    else
      render json: { errors: d.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @direccion.update(direccion_params)
      render json: @direccion.como_json
    else
      render json: { errors: @direccion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @direccion.destroy!
    # Si se fue la por defecto, la más vieja de las que quedan pasa a serlo: sin por defecto el
    # modal no tendría qué preseleccionar.
    @paciente.direcciones_guardadas.ordenadas.first&.update!(por_defecto: true) unless @paciente.direcciones_guardadas.exists?(por_defecto: true)
    head :no_content
  end

  def por_defecto
    @direccion.update!(por_defecto: true)
    render json: @direccion.como_json
  end

  private

  def check_role!
    return if %w[admin supervisor medico dispensador super_admin].include?(current_user.role)

    render json: { error: 'No autorizado' }, status: :forbidden
  end

  def set_paciente
    @paciente = Paciente.for_club(current_user.club_id).find(params[:paciente_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Paciente no encontrado' }, status: :not_found
  end

  def set_direccion
    @direccion = @paciente.direcciones_guardadas.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Dirección no encontrada' }, status: :not_found
  end

  def direccion_params
    params.require(:direccion).permit(:etiqueta, :calle, :altura, :piso, :depto, :barrio, :ciudad, :por_defecto)
  end
end
