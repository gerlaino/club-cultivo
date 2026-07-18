require 'rails_helper'

RSpec.describe 'GET /plants/kpis', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }

  it 'cuenta por estado: activas (veg+flor), cosechadas, en manicura, descartadas' do
    lote_veg = create(:lote, club: club, sala: sala, estado: 'vegetativo')
    create(:plant, lote: lote_veg, club: club, state: 'vegetativo')
    create(:plant, lote: lote_veg, club: club, state: 'floracion')
    create(:plant, lote: lote_veg, club: club, state: 'descartada')

    lote_man = create(:lote, club: club, sala: sala, estado: 'en_manicura')
    create(:plant, lote: lote_man, club: club, state: 'cosechado')

    lote_cur = create(:lote, club: club, sala: sala, estado: 'curado')
    create(:plant, lote: lote_cur, club: club, state: 'cosechado')

    sign_in_as(admin)
    get '/plants/kpis', headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['activas']).to eq(2)     # vegetativo + floración
    expect(body['cosechadas']).to eq(1)  # cosechado NO en manicura (la del lote curado)
    expect(body['en_manicura']).to eq(1) # cosechado del lote en_manicura (disjunta de cosechadas)
    expect(body['descartadas']).to eq(1)
  end
end
