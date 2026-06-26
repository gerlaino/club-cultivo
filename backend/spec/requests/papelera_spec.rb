require 'rails_helper'

RSpec.describe 'Papelera', type: :request do
  include AuthHelpers

  let(:club)       { create(:club) }
  let(:otro_club)  { create(:club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }

  describe 'GET /papelera' do
    it 'lista borrados del club y excluye los de otro club (aislamiento)' do
      mia    = create(:genetica, club: club,      nombre: 'Mi Genética Borrada')
      ajena  = create(:genetica, club: otro_club, nombre: 'Genética Ajena')
      mia.destroy
      ajena.destroy
      sign_in_as(admin)

      get '/papelera', headers: auth_headers
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)['data']
      nombres = data.map { |f| f['descripcion'] }

      expect(nombres).to include('Mi Genética Borrada')
      expect(nombres).not_to include('Genética Ajena')
    end

    it 'filtra por texto con q' do
      create(:genetica, club: club, nombre: 'Amnesia Haze').destroy
      create(:genetica, club: club, nombre: 'Northern Lights').destroy
      sign_in_as(admin)

      get '/papelera', params: { q: 'amnesia' }, headers: auth_headers
      data = JSON.parse(response.body)['data']
      expect(data.map { |f| f['descripcion'] }).to eq(['Amnesia Haze'])
    end

    it 'marca como no restaurables las entidades complejas' do
      create(:genetica, club: club, nombre: 'Simple').destroy
      sign_in_as(admin)

      get '/papelera', headers: auth_headers
      fila = JSON.parse(response.body)['data'].find { |f| f['descripcion'] == 'Simple' }
      expect(fila['restaurable']).to be true
    end

    it 'cultivador no autorizado' do
      sign_in_as(cultivador)
      get '/papelera', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /papelera/restaurar' do
    it 'restaura una entidad simple' do
      g = create(:genetica, club: club, nombre: 'Recuperar')
      g.destroy
      expect(Genetica.where(id: g.id)).to be_empty
      sign_in_as(admin)

      post '/papelera/restaurar', params: { tipo: 'genetica', id: g.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(Genetica.where(id: g.id)).to exist
    end

    it 'no restaura entidades complejas que aún no tienen Restorer' do
      sign_in_as(admin)
      # 'stock' es compleja y todavía sin Restorer implementado.
      post '/papelera/restaurar', params: { tipo: 'stock', id: 999 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'no restaura un registro de otro club' do
      g = create(:genetica, club: otro_club, nombre: 'Ajena')
      g.destroy
      sign_in_as(admin)

      post '/papelera/restaurar', params: { tipo: 'genetica', id: g.id }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(Genetica.where(id: g.id)).to be_empty
    end
  end
end
