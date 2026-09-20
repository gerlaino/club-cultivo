require 'rails_helper'

# Recetas de nutrientes (20-sep-2026): se arman con insumos del depósito y dosis por litro, y
# se aplican al regar: descuentan del depósito, cuestan al lote, y el registro guarda una copia.
# NO bloquea por stock: el riego ya pasó (decisión de Germán).
RSpec.describe 'Recetas de nutrientes', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'vegetativo', start_date: Date.new(2026, 9, 1)) }
  let(:grow)  { ActsAsTenant.with_tenant(club) { i = club.insumos.create!(nombre: 'Bio-Grow', unidad_medida: 'mililitro', sede: sede, stock_minimo: 100); i.registrar_compra!(cantidad: 1000, costo_total_ars: 20_000, created_by: admin, generar_egreso: false); i } }
  let(:calmag) { ActsAsTenant.with_tenant(club) { i = club.insumos.create!(nombre: 'Cal-Mag', unidad_medida: 'mililitro', sede: sede); i.registrar_compra!(cantidad: 30, costo_total_ars: 3_000, created_by: admin, generar_egreso: false); i } }

  before { sign_in_as(admin) }

  def crear_receta
    post '/recetas', params: { receta: { nombre: 'Vege 2', fase: 'vegetativo', ec_objetivo: 1.4, ph_objetivo: 6.0,
      receta_items_attributes: [{ insumo_id: grow.id, dosis: 2, unidad: 'ml_l' }, { insumo_id: calmag.id, dosis: 1, unidad: 'ml_l' }] } },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created), response.body
    json
  end

  it 'se arma con productos del depósito y dosis exacta por litro' do
    r = crear_receta
    expect(r['items'].map { |i| [i['nombre'], i['dosis'].to_f, i['unidad_label']] }).to eq([['Bio-Grow', 2.0, 'ml/L'], ['Cal-Mag', 1.0, 'ml/L']])
    expect(r['fase_label']).to eq('Vegetativo')
  end

  it 'sin productos no es una receta; una dosis en «tapitas» tampoco' do
    post '/recetas', params: { receta: { nombre: 'Vacía' } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    post '/recetas', params: { receta: { nombre: 'X', receta_items_attributes: [{ insumo_id: grow.id, dosis: 2, unidad: 'tapita' }] } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  describe 'aplicar al regar el lote' do
    it 'descuenta del depósito, cuesta al lote y deja la copia en el registro' do
      r = crear_receta
      post "/lotes/#{lote.id}/registros_ambientales",
           params: { registro_ambiental: { ph: 6.1, ec: 1.5, fertilizacion: true }, nutricion: { receta_id: r['id'], litros: 20 } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body

      n = json['nutricion']
      expect(n['receta_nombre']).to eq('Vege 2')
      expect(n['litros']).to eq(20.0)
      expect(n['items'].map { |i| [i['nombre'], i['cantidad'], i['descontado']] }).to eq([['Bio-Grow', 40.0, 40.0], ['Cal-Mag', 20.0, 20.0]])
      expect(grow.reload.stock_actual.to_f).to eq(960.0)
      expect(calmag.reload.stock_actual.to_f).to eq(10.0)
      # 40 ml a $20/ml + 20 ml a $100/ml
      expect(n['costo_ars']).to eq(2800.0)
      consumos = ActsAsTenant.with_tenant(club) { InsumoConsumo.where(lote_id: lote.id).to_a }
      expect(consumos.size).to eq(2)
      expect(consumos.map(&:registro_ambiental_id).uniq).to eq([json['id']])
      expect(json['faltantes']).to eq([])
    end

    it 'si no alcanza NO bloquea: baja lo que hay y lo dice, o no descuenta ese producto' do
      r = crear_receta
      post "/lotes/#{lote.id}/registros_ambientales",
           params: { registro_ambiental: { fertilizacion: true },
                     nutricion: { receta_id: r['id'], litros: 50, items: [
                       { insumo_id: grow.id, modo_faltante: 'descontar_disponible' },
                       { insumo_id: calmag.id, modo_faltante: 'no_descontar' }] } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      # Bio-Grow: 100 de 1000, alcanza. Cal-Mag: pide 50, hay 30 → no se descuenta.
      expect(json['faltantes'].map { |f| [f['nombre'], f['faltante']] }).to eq([['Cal-Mag', 20.0]])
      expect(calmag.reload.stock_actual.to_f).to eq(30.0)
      item = json['nutricion']['items'].find { |i| i['nombre'] == 'Cal-Mag' }
      expect(item).to include('cantidad' => 50.0, 'descontado' => 0.0, 'faltante' => 50.0)
    end

    it 'con «descontar lo que hay» el producto queda en 0' do
      r = crear_receta
      post "/lotes/#{lote.id}/registros_ambientales",
           params: { registro_ambiental: { fertilizacion: true }, nutricion: { receta_id: r['id'], litros: 50 } },
           headers: auth_headers, as: :json
      expect(calmag.reload.stock_actual.to_f).to eq(0.0)
      expect(json['nutricion']['items'].find { |i| i['nombre'] == 'Cal-Mag' }).to include('descontado' => 30.0, 'faltante' => 20.0)
    end

    it 'las cantidades se pueden corregir a mano ese día' do
      r = crear_receta
      post "/lotes/#{lote.id}/registros_ambientales",
           params: { registro_ambiental: { fertilizacion: true }, nutricion: { receta_id: r['id'], litros: 10, items: [{ insumo_id: grow.id, cantidad: 25 }, { insumo_id: calmag.id, cantidad: 5 }] } },
           headers: auth_headers, as: :json
      expect(grow.reload.stock_actual.to_f).to eq(975.0)
      expect(calmag.reload.stock_actual.to_f).to eq(25.0)
    end

    it 'productos sueltos, sin receta, también descuentan' do
      post "/lotes/#{lote.id}/registros_ambientales",
           params: { registro_ambiental: { fertilizacion: true }, nutricion: { litros: 10, items: [{ insumo_id: grow.id, cantidad: 15 }] } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      expect(json['nutricion']['receta_id']).to be_nil
      expect(grow.reload.stock_actual.to_f).to eq(985.0)
    end

    it '«se fertilizó pero no se especificó cómo»: sin nutrición no toca el depósito' do
      grow
      post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { fertilizacion: true, notas_fertilizacion: 'algo de la mesada' } }, headers: auth_headers, as: :json
      expect(json['nutricion']).to be_nil
      expect(grow.reload.stock_actual.to_f).to eq(1000.0)
    end

    it 'borrar el registro devuelve lo descontado' do
      r = crear_receta
      post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { fertilizacion: true }, nutricion: { receta_id: r['id'], litros: 20 } }, headers: auth_headers, as: :json
      id = json['id']
      delete "/lotes/#{lote.id}/registros_ambientales/#{id}", headers: auth_headers
      expect(response).to have_http_status(:no_content)
      expect(grow.reload.stock_actual.to_f).to eq(1000.0)
      expect(calmag.reload.stock_actual.to_f).to eq(30.0)
    end

    it 'editar la receta después no cambia lo que quedó en el registro' do
      r = crear_receta
      post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { fertilizacion: true }, nutricion: { receta_id: r['id'], litros: 10 } }, headers: auth_headers, as: :json
      reg_id = json['id']
      item_id = r['items'].first['id']
      patch "/recetas/#{r['id']}", params: { receta: { receta_items_attributes: [{ id: item_id, dosis: 5 }] } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      get "/lotes/#{lote.id}/registros_ambientales", headers: auth_headers
      reg = json.find { |x| x['id'] == reg_id }
      expect(reg['nutricion']['items'].first['dosis']).to eq(2.0)
    end
  end

  describe 'aplicar a la sala' do
    it 'descuenta una vez y reparte el costo entre los lotes' do
      r = crear_receta
      otro = create(:lote, club: club, sala: sala, estado: 'vegetativo')
      lote
      post "/salas/#{sala.id}/registrar_sala", params: { registro_ambiental: { temperatura: 24, fertilizacion: true }, nutricion: { receta_id: r['id'], litros: 20 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:created), response.body
      expect(json['lotes_afectados']).to eq(2)
      expect(grow.reload.stock_actual.to_f).to eq(960.0)
      costos = ActsAsTenant.with_tenant(club) { InsumoConsumo.where(insumo_id: grow.id).pluck(:lote_id, :cantidad) }
      expect(costos.map { |_, c| c.to_f }.sum).to eq(40.0)
      expect(costos.map(&:first)).to match_array([lote.id, otro.id])
    end
  end

  it 'dónde se usó: lotes, litros y plata' do
    r = crear_receta
    post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { fertilizacion: true }, nutricion: { receta_id: r['id'], litros: 20 } }, headers: auth_headers, as: :json
    get "/recetas/#{r['id']}", headers: auth_headers
    expect(json['uso']['aplicaciones']).to eq(1)
    expect(json['uso']['lotes'].first).to include('codigo' => lote.codigo, 'litros' => 20.0, 'costo_ars' => 2800.0)
  end

  it 'el insumo dice para cuántos riegos más alcanza' do
    r = crear_receta
    post "/lotes/#{lote.id}/registros_ambientales", params: { registro_ambiental: { fertilizacion: true }, nutricion: { receta_id: r['id'], litros: 20 } }, headers: auth_headers, as: :json
    expect(grow.reload.aplicaciones_estimadas).to eq(24)   # 960 / 40
  end

  it 'otra organización no ve estas recetas' do
    r = crear_receta
    sign_in_as(create(:user, :admin, club: create(:club, features: { 'cultivo' => true })))
    get "/recetas/#{r['id']}", headers: auth_headers
    expect(response).to have_http_status(:not_found)
  end
end
