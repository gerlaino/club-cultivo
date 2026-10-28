# Le crea la cuenta del portal a todo el padrón cuando la organización lo abre
# (`PortalAcceso::HabilitarTodos`). En segundo plano: cada cuenta cifra una clave.
class HabilitarPortalJob < ApplicationJob
  queue_as :default

  def perform(club_id)
    club = Club.find_by(id: club_id)
    PortalAcceso::HabilitarTodos.call(club) if club
  end
end
