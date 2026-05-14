module LecturasAmbientales
  class AiImportsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_cultivador_or_admin
    before_action :set_sala

    # POST /salas/:sala_id/lecturas_ambientales/ai_import
    def create
      unless params[:csv_file].present?
        return render json: { error: 'Se requiere un archivo CSV' }, status: :unprocessable_entity
      end

      csv_content = params[:csv_file].read
      driver      = Sensors::AiCsvDriver.new(@sala, current_user)
      resultado   = driver.importar!(csv_content)

      render json: {
        ok:         true,
        importadas: resultado[:importadas],
        filas:      resultado[:filas],
        errores:    resultado[:errores],
        mensaje:    "Se importaron #{resultado[:importadas]} lecturas de #{resultado[:filas]} filas.",
      }, status: :created

    rescue Sensors::AiCsvDriver::CsvParseError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "AiImportsController error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      render json: { error: 'Error inesperado al procesar el CSV' }, status: :internal_server_error
    end

    private

    def set_sala
      @sala = current_user.club.salas.find(params[:sala_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Sala no encontrada' }, status: :not_found
    end

    def require_cultivador_or_admin
      unless current_user.admin? || current_user.cultivador? || current_user.supervisor?
        render json: { error: 'No autorizado' }, status: :forbidden
      end
    end
  end
end
