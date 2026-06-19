require 'rails_helper'

RSpec.describe 'GET /api/lotes/:lote_id/analisis_laboratorio', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  before { sign_in_as(admin) }

  it 'responde 200 con la lista (regresión: la asociación Lote#analisis_laboratorio existe)' do
    get "/api/lotes/#{lote.id}/analisis_laboratorio", as: :json
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq([])
  end

  it 'devuelve los análisis cargados del lote' do
    AnalisisLaboratorio.create!(lote: lote, club_id: club.id, user: admin, laboratorio: 'Lab X', fecha_analisis: Date.current, thc_pct: 18.5)
    get "/api/lotes/#{lote.id}/analisis_laboratorio", as: :json
    body = JSON.parse(response.body)
    expect(body.size).to eq(1)
    expect(body.first['laboratorio']).to eq('Lab X')
  end
end
