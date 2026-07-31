require 'rails_helper'

# El % de prendimiento es la métrica que se perdía: los esquejes que no agarraban caían en
# "descartada" mezclados con plagas, machos y roturas, y no se podía preguntar cuántos fueron.
RSpec.describe 'GET /api/analytics/prendimiento', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:gen)   { create(:genetica, club: club, nombre: 'Blue Sherbet') }

  def lote_con(plantas:, no_prendieron: 0, estado: 'vegetativo', genetica: nil)
    lote = create(:lote, club: club, sala: sala, estado: estado, genetica: genetica)
    plantas.times { |i| create(:plant, lote: lote, state: 'vegetativo', nombre: "P#{i}") }
    lote.plants.limit(no_prendieron).each do |p|
      p.update_columns(state: 'descartada', motivo_descarte: 'no_prendio')
    end
    lote
  end

  def pedir(params = {})
    get '/api/analytics/prendimiento', params: params
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end

  before { sign_in_as(admin) }

  it 'cuenta las que no prendieron y calcula el porcentaje' do
    lote_con(plantas: 100, no_prendieron: 30)

    g = pedir['global']
    expect(g['intentos']).to eq(100)
    expect(g['no_prendieron']).to eq(30)
    expect(g['prendidas']).to eq(70)
    expect(g['porcentaje']).to eq(70.0)
  end

  # Si las descartadas salieran del denominador, el porcentaje daría siempre 100%.
  it 'las descartadas siguen contando como intento' do
    lote_con(plantas: 10, no_prendieron: 10)

    expect(pedir['global']).to include('intentos' => 10, 'prendidas' => 0, 'porcentaje' => 0.0)
  end

  # Una planta perdida por plaga en floración SÍ había enraizado: no ensucia el prendimiento.
  it 'un descarte por otro motivo no cuenta como que no prendió' do
    lote = lote_con(plantas: 10)
    lote.plants.first.update_columns(state: 'descartada', motivo_descarte: 'plaga')

    expect(pedir['global']).to include('intentos' => 10, 'no_prendieron' => 0, 'porcentaje' => 100.0)
  end

  it 'separa por genética, que es donde el dato sirve' do
    otra = create(:genetica, club: club, nombre: 'Tropicana')
    lote_con(plantas: 100, no_prendieron: 5,  genetica: gen)    # 95%
    lote_con(plantas: 100, no_prendieron: 40, genetica: otra)   # 60%

    por_gen = pedir['por_genetica'].index_by { |g| g['genetica'] }
    expect(por_gen['Blue Sherbet']['porcentaje']).to eq(95.0)
    expect(por_gen['Tropicana']['porcentaje']).to eq(60.0)
  end

  it 'suma varios lotes de la misma genética' do
    lote_con(plantas: 50, no_prendieron: 10, genetica: gen)
    lote_con(plantas: 50, no_prendieron: 0,  genetica: gen)

    fila = pedir['por_genetica'].first
    expect(fila).to include('genetica' => 'Blue Sherbet', 'intentos' => 100, 'no_prendieron' => 10)
  end

  # Un lote que está enraizando AHORA todavía no tiene resultado: incluirlo daría un prendimiento
  # falsamente alto (nadie falló todavía) y movería el promedio.
  it 'no mide un lote que todavía está enraizando' do
    lote_con(plantas: 20, estado: 'esqueje')

    expect(pedir['global']['intentos']).to eq(0)
    expect(pedir['global']['porcentaje']).to be_nil
  end

  it 'sin datos devuelve porcentaje nulo, no 0%' do
    expect(pedir['global']['porcentaje']).to be_nil
  end

  it 'no mezcla lotes de otro club' do
    otro = create(:club)
    otro_admin = create(:user, :admin, club: otro)
    ActsAsTenant.with_tenant(otro) do
      s = create(:sede, club: otro, created_by: otro_admin)
      sa = create(:sala, club: otro, sede: s, created_by: otro_admin)
      l = create(:lote, club: otro, sala: sa, estado: 'vegetativo')
      5.times { |i| create(:plant, lote: l, state: 'vegetativo', nombre: "X#{i}") }
    end
    lote_con(plantas: 10, no_prendieron: 1)

    expect(pedir['global']['intentos']).to eq(10)
  end

  it 'acepta un rango de fechas' do
    viejo = lote_con(plantas: 10, no_prendieron: 10)
    viejo.update_column(:start_date, Date.new(2025, 1, 1))
    lote_con(plantas: 10, no_prendieron: 0)

    expect(pedir(desde: Date.current.beginning_of_year.to_s)['global']['porcentaje']).to eq(100.0)
  end
end

# El descarte de una planta que todavía no tiene raíz ES "no prendió". Obligar a elegirlo agregaría
# fricción sin agregar información, así que se asume — y fuera del enraizado se asume lo contrario.
RSpec.describe 'PATCH /api/plants/:id — motivo estructurado del descarte', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'esqueje') }

  def descartar(planta, extra = {})
    patch "/api/plants/#{planta.id}",
          params: { plant: { state: 'descartada' }, motivo: 'se secó' }.merge(extra)
  end

  before { sign_in_as(admin) }

  it 'descartar algo que estaba enraizando se clasifica como no_prendio' do
    p = create(:plant, lote: lote, state: 'esqueje')
    descartar(p)
    expect(p.reload.motivo_descarte).to eq('no_prendio')
  end

  it 'descartar algo en vegetativo NO ensucia la métrica: va como otro' do
    p = create(:plant, lote: lote, state: 'vegetativo')
    descartar(p)
    expect(p.reload.motivo_descarte).to eq('otro')
  end

  it 'un motivo explícito le gana al default' do
    p = create(:plant, lote: lote, state: 'esqueje')
    descartar(p, motivo_descarte: 'plaga')
    expect(p.reload.motivo_descarte).to eq('plaga')
  end

  it 'un motivo inventado cae al default en vez de guardarse' do
    p = create(:plant, lote: lote, state: 'esqueje')
    descartar(p, motivo_descarte: 'cualquier_cosa')
    expect(p.reload.motivo_descarte).to eq('no_prendio')
  end

  # Si al revivir la planta quedara el motivo, seguiría contando como "no prendió" una que está viva.
  it 'revertir el descarte borra el motivo' do
    p = create(:plant, lote: lote, state: 'esqueje')
    descartar(p)
    patch "/api/plants/#{p.id}", params: { plant: { state: 'esqueje' } }
    expect(p.reload.motivo_descarte).to be_nil
  end
end
