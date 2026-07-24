require 'rails_helper'

# Unidades de negocio editables por club (Finanzas — Bloque 1).
RSpec.describe 'Unidades de negocio', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  describe 'GET /unidades_negocio' do
    before { sign_in_as(admin) }

    it 'siembra las unidades de sistema la primera vez' do
      get '/unidades_negocio', headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      tipos = JSON.parse(response.body).map { |u| u['tipo'] }
      expect(tipos).to include('cultivo', 'dispensario', 'administracion')
    end

    it 'incluye la unidad Bar sólo si el club tiene el feature activo' do
      club.update!(features: club.features.merge('bar' => true))
      get '/unidades_negocio', headers: auth_headers, as: :json
      tipos = JSON.parse(response.body).map { |u| u['tipo'] }
      expect(tipos).to include('bar')
    end
  end

  describe 'POST /unidades_negocio' do
    before { sign_in_as(admin) }

    it 'crea una unidad propia' do
      expect {
        post '/unidades_negocio',
             params: { unidad_negocio: { nombre: 'Eventos', tipo: 'social' } },
             headers: auth_headers, as: :json
      }.to change { club.unidades_negocio.count }.by(1)
      expect(response).to have_http_status(:created)
    end

    it 'acepta un tipo libre (es solo una etiqueta agrupadora)' do
      post '/unidades_negocio',
           params: { unidad_negocio: { nombre: 'Merch', tipo: 'merchandising' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['tipo']).to eq('merchandising')
    end

    it 'rechaza un área sin nombre' do
      post '/unidades_negocio',
           params: { unidad_negocio: { nombre: '', tipo: 'general' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'con crear_deposito crea también un depósito para el área' do
      expect {
        post '/unidades_negocio',
             params: { unidad_negocio: { nombre: 'Eventos', tipo: 'social' }, crear_deposito: true },
             headers: auth_headers, as: :json
      }.to change { club.depositos.count }.by(1)
      expect(response).to have_http_status(:created)
      area = club.unidades_negocio.find_by(nombre: 'Eventos')
      dep  = club.depositos.find_by(unidad_negocio_id: area.id)
      expect(dep.nombre).to eq('Eventos')
      expect(dep.es_sistema).to be(false)
    end
  end

  describe 'DELETE /unidades_negocio/:id' do
    before { sign_in_as(admin) }

    it 'no borra una unidad de sistema' do
      get '/unidades_negocio', headers: auth_headers, as: :json # siembra
      unidad = club.unidades_negocio.find_by(tipo: 'cultivo')
      delete "/unidades_negocio/#{unidad.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    # Regresión del 500: borrar un área PROPIA sin movimientos llegaba a evaluar
    # @unidad.categorias_contables (asociación con class_name mal inferido) → NameError.
    it 'borra un área propia sin movimientos' do
      unidad = ActsAsTenant.with_tenant(club) { club.unidades_negocio.create!(nombre: 'Prueba', tipo: 'general') }
      expect {
        delete "/unidades_negocio/#{unidad.id}", headers: auth_headers, as: :json
      }.to change { club.unidades_negocio.count }.by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'no borra un área con categorías asociadas (avisa desactivar)' do
      unidad = ActsAsTenant.with_tenant(club) do
        u = club.unidades_negocio.create!(nombre: 'Con cat', tipo: 'general')
        club.categorias_contables.create!(nombre: 'Cat', tipo: 'egreso', unidad_negocio: u)
        u
      end
      delete "/unidades_negocio/#{unidad.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'aislamiento por club' do
    it 'no expone unidades de otro club' do
      otro = create(:club)
      ajena = ActsAsTenant.with_tenant(otro) { otro.unidades_negocio.create!(nombre: 'Ajena', tipo: 'general') }
      sign_in_as(admin)
      get '/unidades_negocio', headers: auth_headers, as: :json
      ids = JSON.parse(response.body).map { |u| u['id'] }
      expect(ids).not_to include(ajena.id)
    end
  end
end
