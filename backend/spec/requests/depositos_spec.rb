require 'rails_helper'

RSpec.describe 'Depósitos', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  # Multi-sede: los depósitos ahora viven en una sede. Una sede mixta = Cultivo + General + Dispensario.
  def sembrar_sede!
    ActsAsTenant.with_tenant(club) { club.sedes.exists? || create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  end

  describe 'GET /api/depositos' do
    before { sign_in_as(admin); sembrar_sede! }

    it 'siembra los depósitos de sistema la primera vez' do
      get '/api/depositos', headers: auth_headers
      expect(response).to have_http_status(:ok)
      claves = JSON.parse(response.body).map { |d| d['clave_sistema'] }
      expect(claves).to include('cultivo', 'general', 'dispensacion')
    end
  end

  describe 'POST /api/depositos' do
    before { sign_in_as(admin); sembrar_sede! }

    it 'el admin crea un depósito propio (no de sistema)' do
      expect {
        post '/api/depositos', params: { deposito: { nombre: 'Merchandising' } }, headers: auth_headers, as: :json
      }.to change { ActsAsTenant.with_tenant(club) { club.depositos.count } }.by(1)
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['es_sistema']).to be(false)
    end
  end

  describe 'DELETE /api/depositos/:id' do
    before { sign_in_as(admin); sembrar_sede! }

    it 'no borra un depósito de sistema (sugiere desactivar)' do
      get '/api/depositos', headers: auth_headers # siembra
      cultivo = ActsAsTenant.with_tenant(club) { club.depositos.find_by(clave_sistema: 'cultivo') }
      delete "/api/depositos/#{cultivo.id}", headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'no borra un depósito con productos' do
      dep = ActsAsTenant.with_tenant(club) do
        d = club.depositos.create!(nombre: 'Con productos')
        club.insumos.create!(nombre: 'X', unidad_medida: 'unidad', deposito: d)
        d
      end
      delete "/api/depositos/#{dep.id}", headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'borra un depósito propio vacío' do
      dep = ActsAsTenant.with_tenant(club) { club.depositos.create!(nombre: 'Vacío') }
      delete "/api/depositos/#{dep.id}", headers: auth_headers
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'autorización' do
    it 'un cultivador puede leer pero no crear' do
      cultivador = create(:user, :cultivador, club: club)
      sign_in_as(cultivador)
      get '/api/depositos', headers: auth_headers
      expect(response).to have_http_status(:ok)
      post '/api/depositos', params: { deposito: { nombre: 'X' } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
