class DetectarAlertasJob < ApplicationJob
  queue_as :default

  # Sin filtro de suite acá: el detector es mixto (cultivo + cuenta corriente) y decide
  # detector por detector según lo que el club tenga prendido. Ver AlertaDetectorService.
  def perform(club_id = nil)
    scope = club_id ? Club.operativos.where(id: club_id) : Club.operativos
    cada_club_con(scope: scope) { |club| AlertaDetectorService.new(club).detectar! }
  end
end
