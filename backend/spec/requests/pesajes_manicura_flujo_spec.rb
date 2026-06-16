require 'rails_helper'

# Flujo nuevo de manicura: el manicura crea un pesaje (jornada), registra el peso de
# plantas contra ese pesaje (pesada_id nil, pesaje_manicura_id seteado) y lista los
# pesajes del lote. Regresión de dos bugs:
#   - pesadas_plantas.pesada_id era NOT NULL → registrar_peso del flujo nuevo reventaba.
#   - el serializer sumaba peso_seco_g en Ruby y explotaba con un valor nil.
RSpec.describe 'Flujo de pesajes de manicura', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:manicura) { create(:user, :manicura, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin, kind: 'manicura') }
  let(:lote)     { create(:lote, club: club, sala: sala, estado: 'en_manicura', manicurador: manicura) }
  let!(:planta)  { create(:plant, lote: lote, club: club, state: 'cosechado') }

  before { sign_in_as(manicura) }

  it 'crea un pesaje, registra el peso de una planta y lista sin error 500' do
    # 1. Crear pesaje (jornada)
    post "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    expect(response).to have_http_status(:created)
    pesaje_id = JSON.parse(response.body)['id']

    # 2. Registrar el peso de la planta contra ese pesaje (flujo nuevo, pesada nil)
    post "/plants/#{planta.id}/registrar_peso",
         params: { peso_seco_g: 12.5, pesaje_manicura_id: pesaje_id },
         headers: auth_headers
    expect(response).to have_http_status(:ok)

    pp = PesadaPlanta.find_by(plant_id: planta.id, pesaje_manicura_id: pesaje_id)
    expect(pp).to be_present
    expect(pp.pesada_id).to be_nil

    # 3. Listar pesajes del lote — no debe dar 500
    get "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.first['peso_calculado_g']).to eq(12.5)
  end

  it 'lista sin romper aunque una pesada_planta tenga peso_seco_g nil' do
    pesaje = lote.pesajes_manicura.create!(manicurador: manicura, club: club, fecha_pesaje: Date.current)
    pesaje.pesadas_plantas.create!(plant: planta, peso_humedo_g: 5, peso_seco_g: nil)

    get "/lotes/#{lote.id}/pesajes_manicura", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).first['peso_calculado_g']).to eq(0.0)
  end
end
