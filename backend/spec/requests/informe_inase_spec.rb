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

  # Germán: "aparecen genéticas que no tengo... figuran las eliminadas". Eliminar una genética
  # es `activa: false` (no se borra: puede tener lotes colgando), y el informe leía todas.
  describe 'genéticas archivadas' do
    before { sign_in_as(admin) }

    def nombres
      get '/informes/inase', headers: auth_headers
      JSON.parse(response.body)['geneticas'].map { |g| g['nombre'] }
    end

    it 'no declara una que se archivó sin haber llegado a cultivarse' do
      gen_no.update!(activa: false)

      expect(nombres).not_to include('Casera')
    end

    # El otro extremo sería igual de malo: lo cultivado hay que declararlo aunque después se
    # archive, o el informe no cuadra contra las plantas y los gramos que sí figuran.
    it 'sí declara una archivada que tuvo cultivo' do
      create(:lote, club: club, sala: sala, genetica: gen_no, plants_count: 8, estado: 'vegetativo')
      gen_no.update!(activa: false)

      expect(nombres).to include('Casera')
    end

    it 'la archivada sin cultivo tampoco cuenta en el total' do
      gen_reg   # la que queda en pie
      gen_no.update!(activa: false)

      get '/informes/inase', headers: auth_headers
      expect(JSON.parse(response.body)['total_geneticas']).to eq(1)
    end
  end

  it 'requiere rol auditor o admin' do
    sign_in_as(create(:user, :cultivador, club: club))
    get '/informes/inase', headers: auth_headers
    expect(response).to have_http_status(:forbidden)
  end
end
