require 'rails_helper'

RSpec.describe 'Lote — días objetivo por fase', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:genetica) { create(:genetica, club: club, tiempo_floracion: 60, dias_vegetativo_objetivo: 30, dias_cosecha_objetivo: 14) }

  before { sign_in_as(admin) }

  it 'hereda los días objetivo de la genética al crear el lote' do
    post '/lotes', params: {
      lote: { estado: 'vegetativo', origen: 'esqueje', plants_count: 5,
              start_date: Date.current.to_s, genetica_id: genetica.id },
      sala_id: sala.id
    }, headers: auth_headers, as: :json

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body['dias_vegetativo_objetivo']).to eq(30)
    expect(body['dias_floracion_objetivo']).to eq(60)   # = tiempo_floracion de la genética
    expect(body['dias_cosecha_objetivo']).to eq(14)
  end

  it 'permite sobrescribir el objetivo en el lote' do
    post '/lotes', params: {
      lote: { estado: 'vegetativo', origen: 'esqueje', plants_count: 5,
              start_date: Date.current.to_s, genetica_id: genetica.id,
              dias_floracion_objetivo: 70 },
      sala_id: sala.id
    }, headers: auth_headers, as: :json

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)['dias_floracion_objetivo']).to eq(70)
  end
end
