class AnalisisLaboratorioController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :require_admin_cultivador_supervisor!
  before_action :set_lote
  before_action :set_analisis, only: [:update, :destroy]

  def index
    analisis = @lote.analisis_laboratorio.order(fecha_analisis: :desc)
    render json: analisis.map { |a| serialize(a) }
  end

  def create
    analisis = @lote.analisis_laboratorio.build(analisis_params)
    analisis.club_id = current_user.club_id
    analisis.user    = current_user
    analisis.genetica_id = @lote.genetica_id

    if analisis.save
      render json: serialize(analisis), status: :created
    else
      render json: { errors: analisis.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @analisis.update(analisis_params)
      render json: serialize(@analisis)
    else
      render json: { errors: @analisis.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @analisis.destroy
    head :no_content
  end

  private

  def set_lote
    @lote = current_user.club.lotes.find(params[:lote_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Lote no encontrado' }, status: :not_found
  end

  def set_analisis
    @analisis = @lote.analisis_laboratorio.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Análisis no encontrado' }, status: :not_found
  end

  def require_admin_cultivador_supervisor!
    unless %w[admin supervisor cultivador].include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def analisis_params
    params.require(:analisis_laboratorio).permit(
      :fecha_analisis, :laboratorio, :thc_pct, :cbd_pct, :cbg_pct,
      :terpenos_principales, :notas
    )
  end

  def serialize(a)
    {
      id:                   a.id,
      fecha_analisis:       a.fecha_analisis,
      laboratorio:          a.laboratorio,
      thc_pct:              a.thc_pct&.to_f,
      cbd_pct:              a.cbd_pct&.to_f,
      cbg_pct:              a.cbg_pct&.to_f,
      terpenos_principales: a.terpenos_principales,
      notas:                a.notas,
      user_nombre:          a.user&.nombre_completo,
      created_at:           a.created_at,
    }
  end
end
