require 'rails_helper'

# Los cuatro endpoints de la analítica (el cálculo vive en `Analitica::*`, ver su spec): el
# período —todo el historial por defecto, el selector de siempre si se pide—, el corte de
# «Dónde y cómo» y quién puede entrar.
RSpec.describe 'Analítica — endpoints', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:sala)  { create(:sala, club: club, sede: sede, kind: 'mixta') }
  let(:kush)  { create(:genetica, club: club, nombre: 'Critical Kush') }

  def cerrado!(cuando:, gramos: 300)
    l = create(:lote, club: club, sala: sala, genetica: kush, estado: 'curado', rendimiento_real_g: gramos,
                      plants_count_cosechadas: 10, start_date: cuando - 100)
    l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin, registrado_en: cuando)
    l
  end

  before { sign_in_as(admin) }

  it 'por defecto es todo el historial; con período, lo cosechado en él' do
    cerrado!(cuando: Time.zone.today - 10)
    cerrado!(cuando: Time.zone.today - 400)

    get '/api/analytics/geneticas'
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['periodo']['etiqueta']).to eq('todo el historial')
    expect(body['periodo']['lotes']).to eq(2)
    expect(body['filas'].first['lotes']).to eq(2)

    get '/api/analytics/geneticas', params: { periodo: 'anio' }
    expect(JSON.parse(response.body)['periodo']['lotes']).to eq(1)
  end

  it 'fases, dónde y cómo (con corte) y costo responden' do
    cerrado!(cuando: Time.zone.today - 10)

    get '/api/analytics/fases'
    expect(JSON.parse(response.body)['fases']).to eq(%w[enraizado vegetativo floracion cosecha en_manicura curado])

    get '/api/analytics/donde_y_como', params: { corte: 'metodo' }
    expect(JSON.parse(response.body)['corte']).to eq('metodo')

    get '/api/analytics/costo'
    expect(JSON.parse(response.body)['total']['lotes_sin_costo']).to eq(1)
  end

  it 'no entra quien no administra' do
    sign_in_as(create(:user, :dispensador, club: club))
    get '/api/analytics/geneticas'
    expect(response).to have_http_status(:forbidden)
  end
end
