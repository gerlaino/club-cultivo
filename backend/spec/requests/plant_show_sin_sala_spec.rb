require 'rails_helper'

# Regresión: ver el detalle de una planta cuyo lote quedó sin sala (lotes finalizados
# tienen sala_id: nil) reventaba con 500 porque serialize_plant_detail accedía a
# plant.lote.sala.id sin nil-check.
RSpec.describe 'GET /api/plants/:id — detalle nil-safe', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo') }
  let(:plant) { Plant.create!(lote: lote, club: club, nombre: 'P1', state: 'vegetativo') }

  before { sign_in_as(admin) }

  it 'responde 200 con lote normal (con sala)' do
    plant
    get "/api/plants/#{plant.id}"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['lote']['sala']['nombre']).to eq(sala.nombre)
  end

  it 'no rompe (200) cuando el lote está finalizado sin sala' do
    plant
    lote.update_columns(estado: 'finalizado', sala_id: nil)
    get "/api/plants/#{plant.id}"
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['id']).to eq(plant.id)
    expect(body['lote']['sala']).to be_nil
  end
end
