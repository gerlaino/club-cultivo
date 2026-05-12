require 'rails_helper'

RSpec.describe 'Benchmark', type: :request do
  let(:club)  { create(:club, benchmark_opt_in: false) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:disp)  { create(:user, :dispensador, club: club) }

  describe 'GET /api/benchmark' do
    context 'admin autenticado' do
      before { sign_in_as(admin) }

      it 'devuelve 200 con campos esperados' do
        get '/api/benchmark', headers: auth_headers
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to include('opt_in', 'mi_club')
      end

      it 'refleja opt_in = false por defecto' do
        get '/api/benchmark', headers: auth_headers
        body = JSON.parse(response.body)
        expect(body['opt_in']).to be false
      end

      it 'muestra plataforma nil si no hay clubes opt-in' do
        get '/api/benchmark', headers: auth_headers
        body = JSON.parse(response.body)
        expect(body['plataforma']).to be_nil
      end
    end

    context 'dispensador — no autorizado' do
      before { sign_in_as(disp) }

      it 'devuelve 403' do
        get '/api/benchmark', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'sin autenticar' do
      it 'devuelve 401' do
        get '/api/benchmark'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/public/benchmark' do
    it 'devuelve 200 sin autenticación' do
      get '/api/public/benchmark'
      expect(response).to have_http_status(:ok)
    end

    it 'devuelve disponible: false si hay menos de 3 clubes opt-in' do
      get '/api/public/benchmark'
      body = JSON.parse(response.body)
      expect(body['disponible']).to be false
    end

    it 'devuelve disponible: true cuando hay 3+ clubes opt-in' do
      create_list(:club, 3, benchmark_opt_in: true)
      get '/api/public/benchmark'
      body = JSON.parse(response.body)
      expect(body['disponible']).to be true
      expect(body).to include('metricas', 'clubes_participantes')
    end
  end
end
