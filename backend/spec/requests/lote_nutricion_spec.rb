require 'rails_helper'

# «¿QUÉ RECIBIÓ ESTE LOTE?» (Germán, 29-sep-2026). Lo que se afirma, de lo acordado:
# - cada aplicación con sus productos y cantidades; los totales suman lo APLICADO por producto;
# - lo compartido (la sala regada entera, la cama) se cuenta por la PARTE del lote, no entero;
# - un producto que no salió del depósito cuenta como aplicado y dice por qué no se descontó;
# - lo cargado como texto (fertilización sin especificar, la actividad vieja del historial) entra
#   «sin cantidades»: no se inventa ningún número;
# - la semana es de la fase (V3, F2): dos lotes se comparan alineados al arranque de la floración;
# - la plata sólo la ve administración; otra organización no ve nada.
RSpec.describe 'Nutrición del lote', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo', m2: 4) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo', plants_count: 4, start_date: Date.new(2026, 8, 1)) }
  let(:grow)  { ActsAsTenant.with_tenant(club) { i = club.insumos.create!(nombre: 'Bio-Grow', unidad_medida: 'mililitro', sede: sede); i.registrar_compra!(cantidad: 1000, costo_total_ars: 10_000, created_by: admin, generar_egreso: false); i } }
  let(:calmag) { ActsAsTenant.with_tenant(club) { i = club.insumos.create!(nombre: 'Cal-Mag', unidad_medida: 'mililitro', sede: sede); i.registrar_compra!(cantidad: 10, costo_total_ars: 100, created_by: admin, generar_egreso: false); i } }

  before { sign_in_as(admin) }

  def receta
    @receta ||= begin
      post '/recetas', params: { receta: { nombre: 'Vege', ec_objetivo: 1.2, receta_items_attributes: [
        { insumo_id: grow.id, dosis: 2, unidad: 'ml_l' }, { insumo_id: calmag.id, dosis: 1, unidad: 'ml_l' }] } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      json
    end
  end

  def regar(l = lote, litros: 10, cuando: nil, extra: {}, items: nil)
    post "/lotes/#{l.id}/registros_ambientales",
         params: { registro_ambiental: { fertilizacion: true, ec: 1.3, ph: 6.1, registrado_en: cuando&.iso8601 }.compact.merge(extra),
                   nutricion: { receta_id: receta['id'], litros: litros, items: items }.compact },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
  end

  def nutricion(l = lote)
    get "/lotes/#{l.id}/nutricion", headers: auth_headers
    expect(response).to have_http_status(:ok), response.body
    json
  end

  it 'suma lo aplicado por producto, con litros, EC y plata por planta' do
    regar(litros: 10)   # 20 ml grow + 10 ml calmag
    regar(litros: 5)    # 10 + 5 (calmag: quedan 0 → no alcanza 5)
    n = nutricion
    expect(n['aplicaciones'].size).to eq(2)
    t = n['totales']
    expect(t['litros']).to eq(15.0)
    expect(t['litros_por_planta']).to eq(3.75)
    expect(t['productos'].map { |p| [p['nombre'], p['cantidad']] }).to eq([['Bio-Grow', 30.0], ['Cal-Mag', 15.0]])
    expect(t['productos'].find { |p| p['nombre'] == 'Bio-Grow' }['por_planta']).to eq(7.5)
    expect(t['ec']).to eq(1.3)
    # 30 ml × $10 + 10 ml × $10 (el Cal-Mag que alcanzó)
    expect(t['costo_ars']).to eq(400.0)
  end

  it 'un producto que no se descontó cuenta como aplicado y dice por qué' do
    regar(litros: 20)   # pide 20 ml de Cal-Mag, hay 10
    regar(litros: 10, items: [{ insumo_id: grow.id }, { insumo_id: calmag.id, modo_faltante: 'no_descontar' }])
    apps = nutricion['aplicaciones']
    cal_viejo = apps.last['productos'].find { |p| p['nombre'] == 'Cal-Mag' }
    expect(cal_viejo).to include('cantidad' => 20.0, 'descontado' => 10.0, 'motivo' => 'sin_stock', 'motivo_label' => 'no alcanzó el stock')
    cal_nuevo = apps.first['productos'].find { |p| p['nombre'] == 'Cal-Mag' }
    expect(cal_nuevo).to include('cantidad' => 10.0, 'descontado' => 0.0, 'motivo' => 'no_descontar')
    expect(nutricion['totales']['productos'].find { |p| p['nombre'] == 'Cal-Mag' }).to include('cantidad' => 30.0, 'sin_descontar' => 20.0)
  end

  it 'la sala regada entera: cada lote cuenta SU parte, no el total' do
    otro = create(:lote, club: club, sala: sala, estado: 'vegetativo', plants_count: 4)
    lote
    post "/salas/#{sala.id}/registrar_sala", params: { registro_ambiental: { fertilizacion: true }, nutricion: { receta_id: receta['id'], litros: 10 } },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
    [lote, otro].each do |l|
      a = nutricion(l)['aplicaciones'].first
      expect(a).to include('origen' => 'sala', 'parte' => 0.5, 'litros' => 5.0)
      expect(a['productos'].find { |p| p['nombre'] == 'Bio-Grow' }['cantidad']).to eq(10.0)
    end
  end

  it 'una copia vieja sin «parte» se reparte con la misma regla (iguales en un riego)' do
    otro = create(:lote, club: club, sala: sala, estado: 'vegetativo')
    reg = ActsAsTenant.with_tenant(club) do
      lote.registros_ambientales.create!(club: club, user: admin, registrado_en: Time.current, fertilizacion: true,
        nutricion: { 'receta_nombre' => 'Vieja', 'litros' => 30.0, 'costo_ars' => 300.0,
                     'items' => [{ 'nombre' => 'Bio-Grow', 'unidad' => 'mililitro', 'cantidad' => 60.0, 'descontado' => 60.0, 'insumo_id' => grow.id }],
                     'lotes' => [{ 'id' => lote.id, 'codigo' => lote.codigo }, { 'id' => otro.id, 'codigo' => otro.codigo }, { 'id' => 0, 'codigo' => 'X' }] })
    end
    a = nutricion['aplicaciones'].find { |x| x['id'] == reg.id }
    expect(a['productos'].first['cantidad']).to eq(30.0)   # dos lotes que existen: mitad
  end

  it 'lo cargado como texto entra «sin cantidades»: sin números inventados' do
    post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { fertilizacion: true, notas_fertilizacion: 'bloom a ojo' } }, headers: auth_headers, as: :json
    ActsAsTenant.with_tenant(club) do
      lote.lote_eventos.create!(club: club, user: admin, tipo: 'actividad', categoria: 'fertilizacion', registrado_en: 1.day.ago,
                                descripcion: 'foliar', metadata: { 'producto' => 'Kelp', 'ec' => 0.8 })
    end
    n = nutricion
    textos = n['aplicaciones'].select { |a| a['sin_cantidades'] }.map { |a| a['texto'] }
    expect(textos).to match_array(['bloom a ojo', 'Kelp — foliar'])
    expect(n['totales']).to include('sin_cantidades' => 2, 'litros' => 0.0)
    expect(n['totales']['productos']).to eq([])
  end

  it 'la semana es de la fase: alineada al arranque de la floración' do
    ActsAsTenant.with_tenant(club) do
      lote.lote_eventos.create!(club: club, user: admin, tipo: 'cambio_estado', estado_anterior: 'enraizado', estado_nuevo: 'vegetativo', registrado_en: Time.zone.parse('2026-08-01 10:00'))
      lote.lote_eventos.create!(club: club, user: admin, tipo: 'cambio_estado', estado_anterior: 'vegetativo', estado_nuevo: 'floracion', registrado_en: Time.zone.parse('2026-09-01 10:00'))
    end
    regar(cuando: Time.zone.parse('2026-08-16 12:00'))   # día 15 de vege → V3
    regar(cuando: Time.zone.parse('2026-09-09 12:00'))   # día 8 de flora → F2
    n = nutricion
    expect(n['aplicaciones'].map { |a| a['semana_label'] }).to eq(%w[F2 V3])
    expect(n['por_semana'].map { |w| w['semana_label'] }).to eq(%w[V3 F2])
    expect(n['por_fase'].keys).to match_array(%w[vegetativo floracion])
  end

  it 'en la cama: lo que se le puso cuenta por los m² de cada lote' do
    post '/camas', params: { cama: { sala_id: sala.id, nombre: 'Cama A', largo_m: 2, ancho_m: 1, profundidad_cm: 30 } }, headers: auth_headers, as: :json
    cama = json
    post '/lotes', params: { lote: { cama_id: cama['id'], estado: 'vegetativo', plants_count: 2, start_date: Time.zone.today, m2_ocupados: 0.5 } }, headers: auth_headers, as: :json
    chico = json
    post '/lotes', params: { lote: { cama_id: cama['id'], estado: 'vegetativo', plants_count: 2, start_date: Time.zone.today, m2_ocupados: 1.5 } }, headers: auth_headers, as: :json
    grande = json
    post "/camas/#{cama['id']}/registros", params: { registro: { tipo: 'cobertura' }, nutricion: { items: [{ insumo_id: grow.id, cantidad: 100 }] } },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
    get "/lotes/#{chico['id']}/nutricion", headers: auth_headers
    a = json['aplicaciones'].find { |x| x['origen'] == 'cama' }
    expect(a['parte']).to eq(0.25)
    expect(a['productos'].first['cantidad']).to eq(25.0)
    get "/lotes/#{grande['id']}/nutricion", headers: auth_headers
    expect(json['aplicaciones'].find { |x| x['origen'] == 'cama' }['productos'].first['cantidad']).to eq(75.0)
  end

  it 'el historial del lote dice qué productos y la salvedad si no se descontó' do
    regar(litros: 20)
    get "/lotes/#{lote.id}/historial", headers: auth_headers
    reg = json['historial'].find { |i| i['source'] == 'registro_ambiental' }
    expect(reg['detalle']).to include('Vege · 20 L')
    expect(reg['detalle']).to include('Bio-Grow 40 ml')
    expect(reg['detalle']).to include('Cal-Mag 20 ml (sin descontar: no alcanzó el stock)')
  end

  it 'el cultivador ve lo aplicado, no la plata' do
    regar
    sign_in_as(create(:user, :cultivador, club: club))
    n = nutricion
    expect(n['con_costo']).to be(false)
    expect(n['totales']).not_to have_key('costo_ars')
    expect(n['aplicaciones'].first).not_to have_key('costo_ars')
    expect(n['totales']['productos'].size).to eq(2)
  end

  it 'otra organización no ve la nutrición de este lote' do
    regar
    otro = create(:club, features: { 'cultivo' => true })
    sign_in_as(ActsAsTenant.with_tenant(otro) { create(:user, :admin, club: otro) })
    get "/lotes/#{lote.id}/nutricion", headers: auth_headers
    expect(response).to have_http_status(:not_found)
  end
end
