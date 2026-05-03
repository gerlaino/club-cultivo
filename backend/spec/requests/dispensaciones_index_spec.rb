require 'rails_helper'

RSpec.describe 'GET /dispensaciones', type: :request do
  let(:club)        { create(:club) }
  let(:sede)        { create(:sede, club: club) }
  let(:admin)       { create(:user, :admin,       club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:cultivador)  { create(:user, :cultivador,  club: club) }
  let(:otro_club)   { create(:club) }
  let(:otro_dispensador) { create(:user, :dispensador, club: otro_club) }

  context 'dispensador del mismo club — sin fecha (default hoy)' do
    before { sign_in_as(dispensador) }

    it 'devuelve 200 con array dispensaciones' do
      get '/dispensaciones', headers: auth_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to have_key('dispensaciones')
      expect(body['dispensaciones']).to be_an(Array)
    end
  end

  context 'dispensador del mismo club — con fecha explícita' do
    before { sign_in_as(dispensador) }

    it 'devuelve 200 para fecha válida' do
      get '/dispensaciones', params: { fecha: '2026-04-01' }, headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end

  context 'admin del club' do
    before { sign_in_as(admin) }

    it 'devuelve 200' do
      get '/dispensaciones', headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end

  context 'cultivador' do
    before { sign_in_as(cultivador) }

    it 'devuelve 403' do
      get '/dispensaciones', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'dispensador de otro club' do
    before { sign_in_as(otro_dispensador) }

    it 'devuelve 200 pero solo ve dispensaciones de su club' do
      get '/dispensaciones', headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end

  context 'fecha inválida' do
    before { sign_in_as(dispensador) }

    it 'devuelve 422' do
      get '/dispensaciones', params: { fecha: 'no-es-fecha' }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
