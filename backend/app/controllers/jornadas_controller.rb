class JornadasController < ApplicationController
  before_action :authenticate_user!
  before_action :check_rol!
  before_action :set_jornada, only: [:update, :destroy]

  # GET /api/jornadas?anio=&mes=&user_id=
  # El propio usuario ve las suyas; admin/supervisor pueden ver las de cualquiera del club.
  def index
    anio = (params[:anio] || Date.current.year).to_i
    mes  = (params[:mes]  || Date.current.month).to_i

    scope = current_user.club.jornadas_laborales.del_mes(anio, mes).includes(:user)
    scope = scope.where(user_id: target_user_id)
    jornadas = scope.order(:fecha).map { |j| serialize(j) }

    render json: {
      anio: anio, mes: mes,
      total_horas: jornadas.sum { |j| j[:horas] }.round(2),
      jornadas: jornadas,
    }
  end

  # POST /api/jornadas
  def create
    j = current_user.club.jornadas_laborales.new(jornada_params)
    j.user_id = target_user_id_for_write
    if j.save
      render json: serialize(j), status: :created
    else
      render json: { errors: j.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/jornadas/:id
  def update
    if @jornada.update(jornada_params.except(:user_id))
      render json: serialize(@jornada)
    else
      render json: { errors: @jornada.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/jornadas/:id
  def destroy
    @jornada.destroy
    head :no_content
  end

  private

  def admin_o_sup?
    current_user.admin? || current_user.supervisor? || current_user.super_admin?
  end

  def check_rol!
    permitidos = %w[manicura cultivador admin supervisor super_admin]
    render json: { error: 'No autorizado' }, status: :forbidden unless permitidos.include?(current_user.role)
  end

  # A quién pertenecen las jornadas que se listan.
  def target_user_id
    return current_user.id unless admin_o_sup?
    params[:user_id].presence&.to_i || current_user.id
  end

  # En escritura: el propio usuario carga las suyas; admin puede cargar/corregir las de otro.
  def target_user_id_for_write
    return current_user.id unless admin_o_sup?
    uid = params.dig(:jornada, :user_id).presence || params[:user_id].presence
    uid ? uid.to_i : current_user.id
  end

  def set_jornada
    @jornada = current_user.club.jornadas_laborales.find(params[:id])
    # Solo el dueño o un admin/supervisor pueden tocarla.
    unless admin_o_sup? || @jornada.user_id == current_user.id
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Jornada no encontrada' }, status: :not_found
  end

  def jornada_params
    params.require(:jornada).permit(:fecha, :hora_entrada, :hora_salida, :nota)
  end

  def serialize(j)
    {
      id:           j.id,
      user_id:      j.user_id,
      user_nombre:  j.user&.nombre_completo,
      fecha:        j.fecha,
      hora_entrada: j.hora_entrada,
      hora_salida:  j.hora_salida,
      horas:        j.horas,
      nota:         j.nota,
    }
  end
end
