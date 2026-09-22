require 'rails_helper'

# Los m² de cultivo (22-sep-2026, Germán). Tres reglas: la suma de los lotes no puede pasar la
# superficie de la sala; **nunca bloquean** (se crean salas y lotes sin metros, y los informes
# salen igual); y donde falta el dato se dice, en vez de mostrar un número inventado.
RSpec.describe 'Superficie de cultivo (m²)', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:carpa) { create(:sala, club: club, sede: sede, created_by: admin, nombre: 'Carpa', m2: 2) }
  let(:gen)   { create(:genetica, club: club, nombre: 'Kush', rendimiento: 450) }

  before { sign_in_as(admin) }

  it 'una sala se crea sin metros: es opcional' do
    post '/salas', params: { sala: { nombre: 'Sin metros', kind: 'mixta', sede_id: sede.id } }, headers: auth_headers
    expect(response).to have_http_status(:created), response.body
    expect(json['m2']).to be_nil
  end

  it 'los lotes de una sala no pueden sumar más metros que la sala' do
    create(:lote, club: club, sala: carpa, genetica: gen, estado: 'vegetativo', start_date: 5.days.ago.to_date,
                  tamanio_maceta: 7, m2_ocupados: 1.5)

    post '/lotes', params: { sala_id: carpa.id, lote: { codigo: 'L-2', estado: 'vegetativo', start_date: Time.zone.today,
                                                        plants_count: 1, tamanio_maceta: 7, m2_ocupados: 1 } }, headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('quedan 0.5 m²')

    post '/lotes', params: { sala_id: carpa.id, lote: { codigo: 'L-2', estado: 'vegetativo', start_date: Time.zone.today,
                                                        plants_count: 1, tamanio_maceta: 7, m2_ocupados: 0.5 } }, headers: auth_headers
    expect(response).to have_http_status(:created), response.body
    expect(carpa.reload.m2_libres.to_f).to eq(0.0)
  end

  it 'sin metros propios, un lote solo en su sala usa los de la sala; si comparte, no se inventa' do
    solo = create(:lote, club: club, sala: carpa, genetica: gen, estado: 'cosecha', start_date: 90.days.ago.to_date,
                         tamanio_maceta: 7, rendimiento_real_g: 800)
    get "/lotes/#{solo.id}", headers: auth_headers
    expect(json).to include('m2_efectivos' => 2.0, 'rendimiento_g_m2' => 400.0)

    create(:lote, club: club, sala: carpa, genetica: gen, estado: 'vegetativo', start_date: 2.days.ago.to_date, tamanio_maceta: 7)
    get "/lotes/#{solo.id}", headers: auth_headers
    expect(json).to include('m2_efectivos' => nil, 'rendimiento_g_m2' => nil)
  end

  # Al cosechar el lote sale de la sala: si los metros no quedaran guardados, el rendimiento por
  # metro se perdería justo cuando se informa.
  it 'al cosechar, los metros del espacio quedan congelados en el lote' do
    lote = create(:lote, club: club, sala: carpa, genetica: gen, estado: 'floracion', start_date: 90.days.ago.to_date,
                         tamanio_maceta: 7)
    create(:plant, lote: lote, state: 'floracion')

    post "/lotes/#{lote.id}/cosechar_plantas", params: { plantas_ids: lote.plants.pluck(:id), peso_total_g: 900 }, headers: auth_headers
    expect(response).to have_http_status(:created), response.body

    lote.reload
    expect(lote).to have_attributes(estado: 'cosecha', sala_id: nil, m2_ocupados: 2)
    lote.update!(rendimiento_real_g: 900)
    expect(lote.rendimiento_g_m2.to_f).to eq(450.0)
  end

  it 'el CSV de lotes lleva los m² y el g/m²' do
    create(:lote, club: club, sala: carpa, genetica: gen, estado: 'curado', start_date: 100.days.ago.to_date,
                  codigo: 'L-CSV', tamanio_maceta: 7, rendimiento_real_g: 900, m2_ocupados: 2)
    get '/lotes/export_csv', headers: auth_headers
    expect(response.body.lines.first).to include('m²;g/m²')
    expect(response.body).to include('L-CSV').and include(';2.0;450.0;')
  end

  it 'el informe sale igual sin metros, comparando contra la ficha en g/m² y avisando qué falta' do
    con = create(:lote, club: club, sala: carpa, genetica: gen, estado: 'curado', start_date: 100.days.ago.to_date,
                        tamanio_maceta: 7, rendimiento_real_g: 900, plants_count_cosechadas: 4, m2_ocupados: 2)
    otra = create(:sala, club: club, sede: sede, created_by: admin, nombre: 'Sin metros')
    create(:lote, club: club, sala: otra, genetica: gen, estado: 'curado', start_date: 100.days.ago.to_date,
                  tamanio_maceta: 7, rendimiento_real_g: 500, plants_count_cosechadas: 3)

    get '/informes/plan_vs_real', headers: auth_headers
    expect(response).to have_http_status(:ok), response.body

    fila = json['geneticas'].find { |f| f['genetica'] == 'Kush' }
    # 900 g en 2 m² = 450 g/m², justo lo que dice la ficha. El lote sin metros no ensucia el número.
    expect(fila).to include('g_m2_ficha' => 450, 'g_m2_real' => 450.0, 'lotes_sin_m2' => 1)
    expect(fila['frase']).to include('rinde lo que dice su ficha')
    expect(json['aviso_sin_metros']).to include('lotes' => 1, 'de' => 2)
    expect(json['aviso_sin_metros']['texto']).to include('no tienen los m²')
    expect(con.reload.rendimiento_g_m2.to_f).to eq(450.0)
  end
end
