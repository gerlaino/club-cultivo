require 'rails_helper'

# Regresión: GET /plants?lote_id serializa peso_es_promedio (de la pesada de manicura
# más reciente). Antes daba 500 porque Plant no tenía la asociación :pesadas_plantas.
RSpec.describe 'GET /plants?lote_id', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'en_manicura') }
  let!(:plant_medida)  { create(:plant, lote: lote, club: club, state: 'cosechado') }
  let!(:plant_promedio){ create(:plant, lote: lote, club: club, state: 'cosechado') }

  before do
    pesaje = lote.pesajes_manicura.create!(manicurador: admin, club: club, fecha_pesaje: Date.current)
    pesaje.pesadas_plantas.create!(plant: plant_medida,   peso_seco_g: 12, es_promedio: false)
    pesaje.pesadas_plantas.create!(plant: plant_promedio, peso_seco_g: 10, es_promedio: true)
    sign_in_as(admin)
  end

  it 'responde 200 y expone peso_es_promedio por planta' do
    get '/plants', params: { lote_id: lote.id }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    medida   = body.find { |p| p['id'] == plant_medida.id }
    promedio = body.find { |p| p['id'] == plant_promedio.id }
    expect(medida['peso_es_promedio']).to be(false)
    expect(promedio['peso_es_promedio']).to be(true)
  end
end
