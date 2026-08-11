require 'rails_helper'

# El QR de una planta codifica `<origen>/p/<codigo>`, y en producción el SPA se sirve desde el
# MISMO origen que la API. Si /p existe como ruta de Rails a nivel root, el router se come la
# navegación del navegador y devuelve JSON: el HTML del SPA no carga nunca y quien escanea ve
# una pantalla vacía. Es la misma trampa que ya estaba documentada para /c y /d.
RSpec.describe 'Rutas del QR público', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:plant) do
    ActsAsTenant.with_tenant(club) do
      lote = create(:lote, club: club)
      create(:plant, lote: lote, codigo_qr: 'QR-PLANTA-1')
    end
  end

  describe 'a nivel root' do
    # `spa_fallback` responde 404 cuando no hay build (en test no lo hay). Lo que importa es que
    # NO devuelva el JSON de la planta: si lo hiciera, sería el router comiéndose la página.
    it '/p/:codigo_qr NO lo maneja la API: la navegación es del SPA' do
      plant
      get "/p/#{plant.codigo_qr}"

      expect(response.body).not_to include('codigo_qr')
      expect(response.content_type.to_s).not_to include('application/json') if response.ok?
    end

    it '/s/:codigo_qr tampoco' do
      get '/s/QR-STOCK-1'

      expect(response.body).not_to include('forma_producto')
    end
  end

  describe 'bajo /api, que es de donde los pide el frontend' do
    it 'devuelve los datos de la planta' do
      plant
      get "/api/p/#{plant.codigo_qr}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['codigo_qr']).to eq('QR-PLANTA-1')
      expect(body['club_nombre']).to eq(club.name)
    end

    it 'un código que no existe devuelve 404, no una pantalla vacía' do
      get '/api/p/NO-EXISTE'

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to be_present
    end
  end
end
