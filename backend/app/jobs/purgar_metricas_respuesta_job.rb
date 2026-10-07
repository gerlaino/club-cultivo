# Las métricas de tiempos sirven para comparar días, no meses: más de 30 días no se miran.
class PurgarMetricasRespuestaJob < ApplicationJob
  queue_as :default
  DIAS = 30

  def perform
    ActiveRecord::Base.connection.exec_query(
      'DELETE FROM metricas_respuesta WHERE hora < $1', 'Metricas', [DIAS.days.ago])
  end
end
