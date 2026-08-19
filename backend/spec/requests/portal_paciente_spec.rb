require 'rails_helper'

# AC: lo que la organización le muestra a sus miembros es del MIEMBRO y de SU organización.
#
# Antes vivía bajo `Public::` y no pedía login: `Public::BaseController#current_club` era
# `Club.first` con un TODO, así que la web multi-club nunca funcionó y cualquiera que supiera la
# URL leía el catálogo de la organización número uno. Este spec fija las tres condiciones que
# antes no se cumplían: hace falta sesión, hace falta el módulo, y el club sale del usuario.
RSpec.describe 'Portal del paciente', type: :request do
  include AuthHelpers

  let(:club)     { create(:club, features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }
  let(:paciente) { create(:user, :paciente, club: club) }

  RUTAS = %w[club geneticas noticias eventos galeria].freeze

  def entrar(ruta) = get "/api/portal/#{ruta}"

  describe 'sin sesión' do
    it 'no entrega nada' do
      RUTAS.each do |ruta|
        entrar(ruta)
        expect(response).to have_http_status(:unauthorized), "#{ruta} contestó #{response.status} sin login"
      end
    end
  end

  describe 'con sesión de paciente y el módulo activo' do
    before { sign_in_as(paciente) }

    it 'entrega las cinco secciones' do
      RUTAS.each do |ruta|
        entrar(ruta)
        expect(response).to have_http_status(:ok), "#{ruta} contestó #{response.status}: #{response.body}"
      end
    end

    it 'el catálogo es el de SU organización y sólo lo publicado' do
      ActsAsTenant.with_tenant(club) do
        create(:genetica, club: club, nombre: 'Publicada', visible_paciente: true)
        create(:genetica, club: club, nombre: 'Guardada',  visible_paciente: false)
      end
      otro = create(:club, features: { 'vista_paciente' => true })
      ActsAsTenant.with_tenant(otro) { create(:genetica, club: otro, nombre: 'Ajena', visible_paciente: true) }

      entrar('geneticas')

      nombres = JSON.parse(response.body)['data'].map { |g| g['nombre'] }
      expect(nombres).to contain_exactly('Publicada')
    end

    it 'la ficha de la organización es la suya, no la primera de la base' do
      create(:club, name: 'La Primera') # existe antes en la tabla y NO tiene que salir
      entrar('club')

      expect(JSON.parse(response.body)['id']).to eq(club.id)
    end
  end

  describe 'sin el módulo contratado' do
    let(:club) { create(:club, features: { 'produccion_dispensa' => true }) }

    before { sign_in_as(paciente) }

    it 'no se llega: es lo que la organización paga' do
      RUTAS.each do |ruta|
        entrar(ruta)
        expect(response).to have_http_status(:forbidden), "#{ruta} contestó #{response.status} sin el módulo"
      end
    end
  end

  # No es una sección de operación: quien atiende el mostrador o cultiva no entra acá.
  describe 'con otro rol de la organización' do
    it 'el dispensador no entra' do
      sign_in_as(create(:user, :dispensador, club: club))
      entrar('geneticas')

      expect(response).to have_http_status(:forbidden)
    end

    it 'el admin sí: necesita ver lo que va a ver su gente antes de prenderlo' do
      sign_in_as(create(:user, :admin, club: club))
      entrar('geneticas')

      expect(response).to have_http_status(:ok), response.body
    end
  end
end
