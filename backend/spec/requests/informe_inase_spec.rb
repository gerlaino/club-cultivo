require 'rails_helper'

RSpec.describe 'GET /informes/inase', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:gen_reg) { create(:genetica, club: club, nombre: 'Lemon', registrada_inase: true, numero_registro_inase: 'INASE-123', categoria_inase: 'semilla_feminizada') }
  let(:gen_no)  { create(:genetica, club: club, nombre: 'Casera') }

  it 'liga cada genética con su producción real (lotes/plantas/gramos)' do
    sign_in_as(admin)
    create(:lote, club: club, sala: sala, genetica: gen_reg, plants_count: 10, rendimiento_real_g: 500, estado: 'finalizado')
    create(:lote, club: club, sala: sala, genetica: gen_reg, plants_count: 5,  rendimiento_real_g: 250, estado: 'curado')
    create(:lote, club: club, sala: sala, genetica: gen_no,  plants_count: 8,  estado: 'vegetativo')

    get '/informes/inase', headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    expect(body['total_geneticas']).to eq(2)
    expect(body['registradas_inase']).to eq(1)
    expect(body['sin_registrar']).to eq(1)

    lemon = body['geneticas'].find { |g| g['nombre'] == 'Lemon' }
    expect(lemon['registrada_inase']).to be(true)
    expect(lemon['numero_registro_inase']).to eq('INASE-123')
    expect(lemon['lotes']).to eq(2)
    expect(lemon['plantas']).to eq(15)
    expect(lemon['gramos_producidos']).to eq(750.0)
  end

  it 'requiere rol auditor o admin' do
    sign_in_as(create(:user, :cultivador, club: club))
    get '/informes/inase', headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end
end
