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

    # CAMBIO DE CRITERIO (Germán, ago-2026): LOS SECTORES SON CINCO Y NO SE CREAN
    # (UnidadNegocio::CANONICOS). Cada sector propio arrastraba su depósito, así que aparecían
    # varios depósitos para el mismo sector y no había forma de saber cuál era el bueno.
    it 'no deja crear sectores propios' do
      expect {
        post '/unidades_negocio',
             params: { unidad_negocio: { nombre: 'Eventos', tipo: 'social' } },
             headers: auth_headers, as: :json
      }.not_to change { club.unidades_negocio.count }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/fijos/i)
    end

    it 'y por lo tanto tampoco crea depósitos sueltos' do
      expect {
        post '/unidades_negocio',
             params: { unidad_negocio: { nombre: 'Eventos', tipo: 'social' }, crear_deposito: true },
             headers: auth_headers, as: :json
      }.not_to change { club.depositos.count }
    end

    # Se siguen pudiendo renombrar y desactivar: lo que se cierra es inventar sectores nuevos.
    it 'pero sí se puede renombrar uno existente' do
      ActsAsTenant.with_tenant(club) { Finanzas::SembrarCatalogo.new(club).call }
      sector = ActsAsTenant.with_tenant(club) { club.unidades_negocio.find_by(tipo: 'cultivo') }

      patch "/unidades_negocio/#{sector.id}",
            params: { unidad_negocio: { nombre: 'Cultivo Norte' } }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok), response.body
      expect(sector.reload.nombre).to eq('Cultivo Norte')
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
