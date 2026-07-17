require 'rails_helper'

RSpec.describe 'GET /api/plants/por_qr/:codigo_qr', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }
  let!(:plant) { create(:plant, lote: lote) }

  it 'devuelve la planta con el estado del lote (para decidir el destino del QR)' do
    sign_in_as(admin)
    get "/plants/por_qr/#{plant.codigo_qr}", headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['id']).to eq(plant.id)
    expect(body['estado']).to eq(plant.state)
    expect(body['lote']['estado']).to eq(lote.estado)
  end

  it 'no expone una planta de otro club (aislamiento de tenant)' do
    otro_club  = create(:club)
    otro_admin = create(:user, :admin, club: otro_club)
    otra_plant = ActsAsTenant.with_tenant(otro_club) do
      otra_sede  = create(:sede, club: otro_club, created_by: otro_admin)
      otra_sala  = create(:sala, club: otro_club, sede: otra_sede, created_by: otro_admin)
      otro_lote  = create(:lote, club: otro_club, sala: otra_sala)
      create(:plant, lote: otro_lote)
    end

    sign_in_as(admin)
    get "/plants/por_qr/#{otra_plant.codigo_qr}", headers: auth_headers
    expect(response).to have_http_status(:not_found)
  end
end
