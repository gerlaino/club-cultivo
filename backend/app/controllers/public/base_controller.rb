module Public
  class BaseController < ApplicationController
    # No requiere autenticación
    skip_before_action :authenticate_user!, raise: false

    private

    # Helper para obtener el club
    def current_club
      @current_club ||= Club.first # Por ahora club único
      # TODO: Implementar lógica según subdomain o parámetro cuando tengas múltiples clubs
    end
  end
end