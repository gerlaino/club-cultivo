module Medico
  class DisponibilidadController < BaseController
    # GET /api/medico/disponibilidad
    def index
      slots = current_user.disponibilidad_medicos
                          .where(club: club)
                          .activas
                          .order(:dia_semana, :hora_inicio)
      render json: slots.map { |s| serialize(s) }
    end

    # PUT /api/medico/disponibilidad  — reemplaza todo el horario del médico
    def update
      slots_params = params.require(:disponibilidad).map do |s|
        s.permit(:dia_semana, :hora_inicio, :hora_fin)
      end

      ActiveRecord::Base.transaction do
        current_user.disponibilidad_medicos.where(club: club).destroy_all
        slots_params.each do |sp|
          current_user.disponibilidad_medicos.create!(
            club:        club,
            dia_semana:  sp[:dia_semana].to_i,
            hora_inicio: sp[:hora_inicio].to_i,
            hora_fin:    sp[:hora_fin].to_i,
          )
        end
      end

      slots = current_user.disponibilidad_medicos.where(club: club).activas.order(:dia_semana, :hora_inicio)
      render json: slots.map { |s| serialize(s) }
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end

    private

    def serialize(s)
      { id: s.id, dia_semana: s.dia_semana, hora_inicio: s.hora_inicio, hora_fin: s.hora_fin }
    end
  end
end
