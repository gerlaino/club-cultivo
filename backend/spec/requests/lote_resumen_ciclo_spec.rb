require 'rails_helper'

# «Cómo salió» (20-sep-2026): al cerrar un ciclo, todo lo que importa en un solo lugar, con el
# mismo cálculo que la analítica, y contra qué compararlo. Sin ciclos anteriores no se inventa
# una comparación.
RSpec.describe 'Lote — resumen del ciclo', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, plan: 'personal') }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'mixta') }
  let(:gen)   { create(:genetica, club: club) }

  before { sign_in_as(admin) }

  # Un ciclo con su cronología: 10 días enraizando, 30 de vege, 60 de flora, 10 colgado.
  def ciclo_cerrado(codigo:, gramos:, plantas: 4, estado: 'curado')
    inicio = 120.days.ago
    lote = create(:lote, club: club, sala: sala, genetica: gen, codigo: codigo, estado: estado,
                         start_date: inicio.to_date, rendimiento_real_g: gramos, plants_count_cosechadas: plantas,
                         tamanio_maceta: 3)
    plantas.times { create(:plant, lote: lote, state: 'cosechado') }
    [['enraizado', 'vegetativo', 10], ['vegetativo', 'floracion', 40], ['floracion', 'cosecha', 100],
     ['cosecha', 'en_manicura', 110], ['en_manicura', 'curado', 112]].each do |ant, nue, dia|
      lote.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: ant, estado_nuevo: nue,
                                registrado_en: inicio + dia.days, club: club, user: admin)
    end
    lote
  end

  it 'junta gramos, g/planta, días por fase, registros y fotos' do
    lote = ciclo_cerrado(codigo: 'L-1', gramos: 312)
    ActsAsTenant.with_tenant(club) do
      lote.registros_ambientales.create!(club: club, user: admin, registrado_en: 100.days.ago, tareas_realizadas: %w[riego], estado_general: 'bueno')
      lote.registros_ambientales.create!(club: club, user: admin, registrado_en: 99.days.ago, tareas_realizadas: %w[registro_ambiental], estado_general: 'bueno')
    end

    get "/lotes/#{lote.id}/resumen_ciclo", headers: auth_headers
    expect(response).to have_http_status(:ok), response.body

    expect(json).to include('cerrado' => true, 'gramos' => 312.0, 'g_por_planta' => 78.0)
    expect(json['dias']).to include('vegetativo' => 30.0, 'floracion' => 60.0, 'cosecha' => 10.0)
    expect(json['registros']).to eq('total' => 2, 'riegos' => 1)
    expect(json['fotos']).to include('total' => 0)
    expect(json['anterior']).to be_nil
  end

  it 'compara contra los ciclos cerrados anteriores de la misma genética, y sólo contra ésos' do
    ciclo_cerrado(codigo: 'L-0', gramos: 200)                      # anterior: 50 g/planta
    otra = create(:genetica, club: club, nombre: 'Otra')
    ciclo_cerrado(codigo: 'L-X', gramos: 900).update!(genetica: otra)  # otra genética: afuera
    lote = ciclo_cerrado(codigo: 'L-1', gramos: 312)

    get "/lotes/#{lote.id}/resumen_ciclo", headers: auth_headers
    # 102 y no 112: como en la analítica, el enraizado sin evento de entrada no se cuenta.
    expect(json['anterior']).to include('lotes' => 1, 'g_por_planta' => 50.0, 'dias_total' => 102.0)
  end

  it 'un lote todavía en cultivo no está cerrado y no tiene gramos' do
    lote = create(:lote, club: club, sala: sala, genetica: gen, estado: 'vegetativo', start_date: 10.days.ago.to_date)
    get "/lotes/#{lote.id}/resumen_ciclo", headers: auth_headers
    expect(json).to include('cerrado' => false, 'gramos' => nil, 'g_por_planta' => nil)
  end

  # La plata es de administración, como la tarjeta P&L: el cultivador ve el ciclo sin pesos.
  it 'al cultivador le llega sin costo' do
    lote = ciclo_cerrado(codigo: 'L-1', gramos: 312)
    ActsAsTenant.with_tenant(club) { CostoLote.create!(lote: lote, club: club, costo_insumos: 40_000, gramos_producidos: 312) }
    cultivador = create(:user, :cultivador, club: club)
    ActsAsTenant.with_tenant(club) { cultivador.salas << sala if cultivador.respond_to?(:salas) }

    sign_in_as(admin)
    get "/lotes/#{lote.id}/resumen_ciclo", headers: auth_headers
    expect(json['costo']).to include('total' => 40_000.0)

    sign_in_as(cultivador)
    get "/lotes/#{lote.id}/resumen_ciclo", headers: auth_headers
    expect(response).to have_http_status(:ok), response.body
    expect(json['costo']).to be_nil
    expect(json['gramos']).to eq(312.0)
  end

  it 'no muestra el ciclo de otra organización' do
    lote = ciclo_cerrado(codigo: 'L-1', gramos: 312)
    otro_club = create(:club)
    sign_in_as(create(:user, :admin, club: otro_club))

    get "/lotes/#{lote.id}/resumen_ciclo", headers: auth_headers
    expect(response).to have_http_status(:not_found)
  end
end
