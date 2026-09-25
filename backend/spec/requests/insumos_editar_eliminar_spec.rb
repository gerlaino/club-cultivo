require 'rails_helper'

# AC (Germán, 25-sep-2026, «Mis nutrientes»): «¿cómo hago para editar o eliminar un producto?».
# Acordado: editar (nombre, unidad, aviso de poco), corregir la cantidad con motivo, y eliminar:
# si nunca se usó se borra; si se usó o está en una receta, NO se borra y se ofrece archivar.
RSpec.describe 'Editar y eliminar un nutriente', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  def nutriente(nombre = 'Base A', compra: nil)
    ActsAsTenant.with_tenant(club) do
      i = club.insumos.create!(nombre: nombre, unidad_medida: 'mililitro', sede: sede, tipo: 'cultivo')
      i.registrar_compra!(cantidad: compra, costo_total_ars: 10_000, created_by: admin, generar_egreso: false) if compra
      i
    end
  end

  before { sign_in_as(admin) }

  describe 'editar' do
    it 'cambia el nombre y el aviso de «queda poco»' do
      i = nutriente

      put "/insumos/#{i.id}", params: { insumo: { nombre: 'Base A (Canna)', stock_minimo: 200 } }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(i.reload).to have_attributes(nombre: 'Base A (Canna)', stock_minimo: 200)
    end

    it 'sin compras ni riegos, la unidad se puede cambiar' do
      i = nutriente

      put "/insumos/#{i.id}", params: { insumo: { unidad_medida: 'gramo' } }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(i.reload.unidad_medida).to eq('gramo')
    end

    # 1000 ml no pueden pasar a leerse como 1000 g.
    it 'con compras cargadas, la unidad no se cambia' do
      i = nutriente(compra: 1000)

      put "/insumos/#{i.id}", params: { insumo: { unidad_medida: 'gramo' } }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].join).to include('unidad')
      expect(i.reload.unidad_medida).to eq('mililitro')
    end
  end

  describe 'corregir la cantidad' do
    it 'por error de carga, queda lo que se contó' do
      i = nutriente(compra: 1000)

      post "/insumos/#{i.id}/reconteo", params: { nuevo_stock: 800, motivo: 'correccion' }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok), response.body
      expect(i.reload.stock_actual).to eq(800)
    end

    it 'por derrame o vencido baja, y no puede subir' do
      i = nutriente(compra: 1000)

      post "/insumos/#{i.id}/reconteo", params: { nuevo_stock: 1200, motivo: 'merma' }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(i.reload.stock_actual).to eq(1000)
    end
  end

  describe 'eliminar' do
    it 'uno que nunca se usó se borra' do
      i = nutriente

      delete "/insumos/#{i.id}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(Insumo.unscoped.find(i.id).deleted_at).to be_present
    end

    # Antes lo sacaba en silencio de la receta, que quedaba con un producto menos.
    it 'uno que está en una receta no se borra: dice en cuál y ofrece archivar' do
      i = nutriente(compra: 1000)
      post '/recetas', params: { receta: { nombre: 'Vege 2', receta_items_attributes: [{ insumo_id: i.id, dosis: 2, unidad: 'ml_l' }] } },
                       headers: auth_headers, as: :json
      receta_id = json['id']

      delete "/insumos/#{i.id}", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('«Vege 2»')
      expect(json['puede_archivar']).to be(true)
      expect(i.reload.deleted_at).to be_nil
      expect(ActsAsTenant.with_tenant(club) { RecetaItem.where(receta_id: receta_id, insumo_id: i.id).count }).to eq(1)
    end

    it 'uno que ya se usó no se borra y ofrece archivar' do
      i = nutriente(compra: 1000)
      ActsAsTenant.with_tenant(club) { i.registrar_consumo!(cantidad: 50, created_by: admin) }

      delete "/insumos/#{i.id}", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['puede_archivar']).to be(true)
    end

    it 'archivado deja de aparecer en la lista de nutrientes' do
      i = nutriente(compra: 1000)

      put "/insumos/#{i.id}", params: { insumo: { activo: false } }, headers: auth_headers, as: :json
      get '/insumos', params: { tipo: 'cultivo', activos: 'true' }, headers: auth_headers

      lista = json.is_a?(Hash) ? json['insumos'] : json
      expect(lista.map { |x| x['id'] }).not_to include(i.id)
    end
  end

  it 'no deja tocar el nutriente de otra organización' do
    otro = create(:club)
    ajeno = ActsAsTenant.with_tenant(otro) { otro.insumos.create!(nombre: 'Ajeno', unidad_medida: 'mililitro', tipo: 'cultivo') }

    delete "/insumos/#{ajeno.id}", headers: auth_headers
    expect(response.status).to be_in([403, 404])
    put "/insumos/#{ajeno.id}", params: { insumo: { nombre: 'X' } }, headers: auth_headers, as: :json
    expect(response.status).to be_in([403, 404])
    expect(ActsAsTenant.with_tenant(otro) { ajeno.reload.nombre }).to eq('Ajeno')
  end
end
