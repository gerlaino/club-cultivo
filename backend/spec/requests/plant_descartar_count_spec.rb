require 'rails_helper'

RSpec.describe 'Conteo de plantas vivas del lote', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, plants_count: 0, estado: 'vegetativo') }
  let!(:plantas) do
    3.times.map { |i| Plant.create!(lote: lote, club: club, nombre: "P#{i}", state: 'vegetativo') }
  end

  before do
    lote.update_column(:plants_count, 3)
    sign_in_as(admin)
  end

  it 'descartar una planta decrementa plants_count' do
    patch "/plants/#{plantas.first.id}", params: { plant: { state: 'descartada' } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(lote.reload.plants_count).to eq(2)
  end

  it 'revertir el descarte vuelve a incrementar' do
    patch "/plants/#{plantas.first.id}", params: { plant: { state: 'descartada' } }, headers: auth_headers, as: :json
    patch "/plants/#{plantas.first.id}", params: { plant: { state: 'vegetativo' } }, headers: auth_headers, as: :json
    expect(lote.reload.plants_count).to eq(3)
  end

  it 'el detalle de sala muestra el conteo vivo (sin descartadas)' do
    plantas.first.update!(state: 'descartada')
    get "/salas/#{sala.id}", headers: auth_headers
    body = JSON.parse(response.body)
    lote_json = (body['lotes'] || []).find { |l| l['id'] == lote.id }
    expect(lote_json['plants_count']).to eq(2)   # 3 - 1 descartada
  end
end
