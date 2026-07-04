class CsvImportJob < ApplicationJob
  queue_as :ambiente

  discard_on ActiveRecord::RecordNotFound

  def perform(dispositivo_id, csv_content)
    dispositivo = Dispositivo.find(dispositivo_id)
    ActsAsTenant.with_tenant(dispositivo.club) do
      driver = Sensors::ManualCsvDriver.new(dispositivo)
      driver.persist!(csv_content)
      EvaluarReglasJob.perform_later(dispositivo.sala_id)
    end
  end
end
