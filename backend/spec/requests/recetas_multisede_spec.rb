require 'rails_helper'

# RECETAS CON VARIAS SEDES (29-sep-2026). La receta es de la organización («es conocimiento»);
# el depósito del que se descuenta lo decide la sala donde se aplica. Antes la receta apuntaba a
# la fila de insumo de UNA sede y regar en la otra descontaba de la primera.
# Lo que se afirma:
# - regar en la sede B descuenta el producto de B (mismo nombre y unidad), nunca el de A;
# - si SÓLO la sede A lo tiene, regar en B no toca A: queda como faltante «no hay en esta sede»
#   y el riego se registra igual (no bloquea por stock);
# - vale para las cuatro puertas: registro del lote, de la sala, riego de la cama y top dress;
# - un producto suelto elegido de otra sede también se resuelve al de la sede;
# - lo del pool (sin sede) lo puede usar cualquier sede;
# - la pantalla ve el id y el stock de SU sede (`?lote_id=`/`?sala_id=`).
RSpec.describe 'Recetas de nutrientes con varias sedes', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)   { create(:club, features: { 'cultivo' => true }) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:sede_a) { create(:sede, club: club, created_by: admin, nombre: 'Sede A') }
  let(:sede_b) { create(:sede, club: club, created_by: admin, nombre: 'Sede B') }
  let(:sala_a) { create(:sala, club: club, sede: sede_a, created_by: admin, kind: 'vegetativo') }
  let(:sala_b) { create(:sala, club: club, sede: sede_b, created_by: admin, kind: 'vegetativo', m2: 2.88) }
  let(:lote_b) { create(:lote, club: club, sala: sala_b, estado: 'vegetativo', start_date: Date.new(2026, 9, 1)) }

  def insumo(nombre, sede, cantidad, costo, unidad: 'mililitro')
    ActsAsTenant.with_tenant(club) do
      i = club.insumos.create!(nombre: nombre, unidad_medida: unidad, sede: sede)
      i.registrar_compra!(cantidad: cantidad, costo_total_ars: costo, created_by: admin, generar_egreso: false) if cantidad.positive?
      i
    end
  end

  let!(:grow_a) { insumo('Bio-Grow', sede_a, 1000, 20_000) }   # $20/ml

  before { sign_in_as(admin) }

  def receta(items, uso: 'riego')
    post '/recetas', params: { receta: { nombre: 'Vege', uso: uso, receta_items_attributes: items } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
    json
  end

  def regar_lote(r, litros: 20, items: nil)
    post "/lotes/#{lote_b.id}/registros_ambientales",
         params: { registro_ambiental: { fertilizacion: true }, nutricion: { receta_id: r&.dig('id'), litros: litros, items: items }.compact },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
    json
  end

  describe 'las dos sedes tienen el producto' do
    let!(:grow_b) { insumo('Bio-Grow', sede_b, 500, 5_000) }    # $10/ml

    it 'regar un lote de la sede B descuenta de B y no toca A, al costo de B' do
      r = receta([{ insumo_id: grow_a.id, dosis: 2, unidad: 'ml_l' }])   # armada con el de A
      res = regar_lote(r)
      expect(grow_b.reload.stock_actual.to_f).to eq(460.0)
      expect(grow_a.reload.stock_actual.to_f).to eq(1000.0)
      expect(res['nutricion']['items'].first).to include('insumo_id' => grow_b.id, 'descontado' => 40.0, 'costo_ars' => 400.0)
      expect(res['faltantes']).to eq([])
    end

    it 'regar la sala de la sede B también descuenta de B' do
      r = receta([{ insumo_id: grow_a.id, dosis: 2, unidad: 'ml_l' }])
      lote_b
      post "/salas/#{sala_b.id}/registrar_sala", params: { registro_ambiental: { fertilizacion: true }, nutricion: { receta_id: r['id'], litros: 20 } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      expect(grow_b.reload.stock_actual.to_f).to eq(460.0)
      expect(grow_a.reload.stock_actual.to_f).to eq(1000.0)
    end

    it 'un producto suelto elegido de la otra sede se descuenta del de esta' do
      regar_lote(nil, items: [{ insumo_id: grow_a.id, cantidad: 15 }])
      expect(grow_b.reload.stock_actual.to_f).to eq(485.0)
      expect(grow_a.reload.stock_actual.to_f).to eq(1000.0)
    end

    it 'el mismo producto se reconoce aunque esté escrito con otras mayúsculas o espacios' do
      grow_b.update!(nombre: ' bio-grow ')
      r = receta([{ insumo_id: grow_a.id, dosis: 1, unidad: 'ml_l' }])
      regar_lote(r, litros: 10)
      expect(grow_b.reload.stock_actual.to_f).to eq(490.0)
      expect(grow_a.reload.stock_actual.to_f).to eq(1000.0)
    end

    it 'con otra unidad NO es el mismo producto' do
      grow_b.update_columns(unidad_medida: 'gramo')
      r = receta([{ insumo_id: grow_a.id, dosis: 1, unidad: 'ml_l' }])
      res = regar_lote(r, litros: 10)
      expect(grow_a.reload.stock_actual.to_f).to eq(1000.0)
      expect(grow_b.reload.stock_actual.to_f).to eq(500.0)
      expect(res['faltantes'].first).to include('sin_en_sede' => true)
    end

    it 'la receta pedida desde el lote de B trae el id y el stock de B; sin contexto, la de siempre' do
      r = receta([{ insumo_id: grow_a.id, dosis: 2, unidad: 'ml_l' }])
      get '/recetas', params: { uso: 'riego', lote_id: lote_b.id }, headers: auth_headers
      item = json.find { |x| x['id'] == r['id'] }['items'].first
      expect(item).to include('insumo_id' => grow_b.id, 'sin_en_sede' => false)
      expect(item['stock_actual'].to_f).to eq(500.0)

      get '/recetas', headers: auth_headers
      item = json.find { |x| x['id'] == r['id'] }['items'].first
      expect(item['insumo_id']).to eq(grow_a.id)
      expect(item['stock_actual'].to_f).to eq(1000.0)
    end

    it 'los productos sueltos que se ofrecen en la sala de B son los de B' do
      get '/insumos', params: { tipo: 'cultivo', sala_id: sala_b.id }, headers: auth_headers
      expect(json['insumos'].map { |i| i['id'] }).to eq([grow_b.id])
    end
  end

  describe 'sólo la sede A tiene el producto' do
    it 'regar en B no toca el depósito de A: queda como faltante y el riego se registra' do
      r = receta([{ insumo_id: grow_a.id, dosis: 2, unidad: 'ml_l' }])
      res = regar_lote(r)
      expect(grow_a.reload.stock_actual.to_f).to eq(1000.0)
      expect(res['faltantes']).to eq([{ 'insumo_id' => grow_a.id, 'nombre' => 'Bio-Grow', 'faltante' => 40.0,
                                        'unidad' => 'mililitro', 'sin_en_sede' => true }])
      expect(res['nutricion']['items'].first).to include('insumo_id' => nil, 'descontado' => 0.0, 'faltante' => 40.0, 'costo_ars' => 0.0)
      expect(ActsAsTenant.with_tenant(club) { InsumoConsumo.count }).to eq(0)
    end

    it 'la receta pedida desde B lo marca: sin stock en esta sede' do
      receta([{ insumo_id: grow_a.id, dosis: 2, unidad: 'ml_l' }])
      get '/recetas', params: { lote_id: lote_b.id }, headers: auth_headers
      expect(json.first['items'].first).to include('insumo_id' => grow_a.id, 'sin_en_sede' => true)
      expect(json.first['items'].first['stock_actual'].to_f).to eq(0.0)
    end

    it 'regar en A (su sede) descuenta de A como siempre' do
      r = receta([{ insumo_id: grow_a.id, dosis: 2, unidad: 'ml_l' }])
      lote_a = create(:lote, club: club, sala: sala_a, estado: 'vegetativo')
      post "/lotes/#{lote_a.id}/registros_ambientales",
           params: { registro_ambiental: { fertilizacion: true }, nutricion: { receta_id: r['id'], litros: 20 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      expect(grow_a.reload.stock_actual.to_f).to eq(960.0)
    end
  end

  it 'lo del pool (sin sede) lo usa cualquier sede' do
    pool = insumo('Cal-Mag', nil, 100, 1_000)
    r = receta([{ insumo_id: pool.id, dosis: 1, unidad: 'ml_l' }])
    regar_lote(r, litros: 10)
    expect(pool.reload.stock_actual.to_f).to eq(90.0)
  end

  describe 'en la cama de la sede B' do
    let!(:harina_a) { insumo('Harina de hueso', sede_a, 10, 50_000, unidad: 'kilogramo') }
    let!(:harina_b) { insumo('Harina de hueso', sede_b, 10, 50_000, unidad: 'kilogramo') }
    let!(:te_b)     { insumo('Bio-Grow', sede_b, 500, 5_000) }

    def cama_b
      post '/camas', params: { cama: { sala_id: sala_b.id, nombre: 'Cama B', largo_m: 1.2, ancho_m: 1.2, profundidad_cm: 30 } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      json
    end

    it 'el top dress descuenta la harina de B' do
      r = receta([{ insumo_id: harina_a.id, dosis: 100, unidad: 'g_m2' }], uso: 'top_dress')
      c = cama_b
      post "/camas/#{c['id']}/registros", params: { registro: { tipo: 'top_dress' }, nutricion: { receta_id: r['id'] } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      expect(harina_b.reload.stock_actual.to_f).to be_within(0.0001).of(10 - 0.144)
      expect(harina_a.reload.stock_actual.to_f).to eq(10.0)
    end

    it 'el té al regar la cama descuenta de B' do
      r = receta([{ insumo_id: grow_a.id, dosis: 2, unidad: 'ml_l' }])
      c = cama_b
      create(:lote, club: club, sala: sala_b, estado: 'vegetativo', cama_id: c['id'])
      post "/camas/#{c['id']}/regar", params: { litros: 10, nutricion: { receta_id: r['id'] } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      expect(te_b.reload.stock_actual.to_f).to eq(480.0)
      expect(grow_a.reload.stock_actual.to_f).to eq(1000.0)
    end
  end

  it 'aislamiento: una sala de otra organización no cambia qué ve esta' do
    otro = create(:club, features: { 'cultivo' => true })
    # Con el tenant fijado en `club`, acts_as_tenant crearía la sala acá: se arma en el suyo.
    otra_sala = ActsAsTenant.with_tenant(otro) do
      otro_admin = create(:user, :admin, club: otro)
      otra_sede = create(:sede, club: otro, created_by: otro_admin)
      create(:sala, club: otro, sede: otra_sede, created_by: otro_admin, kind: 'vegetativo')
    end
    expect(otra_sala.club_id).to eq(otro.id)
    r = receta([{ insumo_id: grow_a.id, dosis: 2, unidad: 'ml_l' }])
    get '/recetas', params: { sala_id: otra_sala.id }, headers: auth_headers
    expect(json.find { |x| x['id'] == r['id'] }['items'].first).to include('insumo_id' => grow_a.id, 'sin_en_sede' => false)
    get '/insumos', params: { sala_id: otra_sala.id }, headers: auth_headers
    expect(json['insumos'].map { |i| i['id'] }).to eq([grow_a.id])
  end
end
