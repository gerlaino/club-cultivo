module LecturasAmbientales
  class ImportsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_cultivador_or_admin
    before_action :set_dispositivo

    def create
      unless params[:csv_file].present?
        return render json: { error: 'Se requiere un archivo CSV' }, status: :unprocessable_entity
      end

      csv_content = params[:csv_file].read
      CsvImportJob.perform_later(@dispositivo.id, csv_content)

      render json: { encolado: true, mensaje: 'Importación iniciada en segundo plano.' }, status: :accepted
    end

    private

    def set_dispositivo
      @dispositivo = current_user.club.dispositivos.find(params[:dispositivo_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Dispositivo no encontrado' }, status: :not_found
    end

    def require_cultivador_or_admin
      unless current_user.admin? || current_user.cultivador?
        render json: { error: 'Forbidden' }, status: :forbidden
      end
    end
  end
end
