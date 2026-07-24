require 'rails_helper'

RSpec.describe 'Categorías de producto', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  describe 'GET /api/categorias_producto' do
    before { sign_in_as(admin) }
    it 'siembra las categorías default la primera vez' do
      get '/api/categorias_producto', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).map { |c| c['nombre'] }).to include('Bebidas', 'Cocina', 'Merchandising')
    end
  end

  describe 'POST /api/categorias_producto' do
    before { sign_in_as(admin) }
    it 'crea una categoría propia (no de sistema)' do
      expect {
        post '/api/categorias_producto', params: { categoria_producto: { nombre: 'Postres' } }, headers: auth_headers, as: :json
      }.to change { ActsAsTenant.with_tenant(club) { club.categorias_producto.count } }.by(1)
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['es_sistema']).to be(false)
    end
  end

  describe 'DELETE /api/categorias_producto/:id' do
    before { sign_in_as(admin) }

    it 'no borra una de sistema (sugiere desactivar)' do
      get '/api/categorias_producto', headers: auth_headers # siembra
      cat = ActsAsTenant.with_tenant(club) { club.categorias_producto.find_by(clave_sistema: 'bebida') }
      delete "/api/categorias_producto/#{cat.id}", headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'no borra una con productos asignados' do
      cat = ActsAsTenant.with_tenant(club) do
        c = club.categorias_producto.create!(nombre: 'Con productos')
        create(:bar_producto, club: club, categoria_producto: c)
        c
      end
      delete "/api/categorias_producto/#{cat.id}", headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'borra una propia vacía' do
      cat = ActsAsTenant.with_tenant(club) { club.categorias_producto.create!(nombre: 'Vacía') }
      delete "/api/categorias_producto/#{cat.id}", headers: auth_headers
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'autorización' do
    it 'un dispensador lee pero no crea' do
      disp = create(:user, :dispensador, club: club)
      sign_in_as(disp)
      get '/api/categorias_producto', headers: auth_headers
      expect(response).to have_http_status(:ok)
      post '/api/categorias_producto', params: { categoria_producto: { nombre: 'X' } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
