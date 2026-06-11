class InformeSemestralController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_autorizado!

  # GET /informe_semestral
  def show
    hoy      = Time.zone.today
    anio     = (params[:anio]     || hoy.year).to_i
    semestre = (params[:semestre] || (hoy.month <= 6 ? 1 : 2)).to_i

    datos = InformeSemestralService.new(current_user.club, anio: anio, semestre: semestre).call
    render json: datos.merge(generado_por: "#{current_user.first_name} #{current_user.last_name}".strip)
  end

  private

  def require_admin_or_autorizado!
    unless current_user.admin? || current_user.role.in?(%w[auditor])
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end
end
