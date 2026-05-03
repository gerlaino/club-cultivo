require 'rails_helper'

RSpec.describe 'ReglasAmbientales', type: :request do
  let(:club)       { create(:club) }
  let(:sala)       { create(:sala, club: club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }
  let(:auditor)    { create(:user, :auditor, club: club) }

  let(:valid_params) do
    {
      regla_ambiental: {
        nombre:           'Temperatura alta',
        tipo_lectura:     'temperatura',
        condicion:        'gt',
        umbral_a:         30.0,
        duracion_minutos: 15,
        prioridad:        'alta',
        accion:           'notificar',
        activa:           true,
        sala_id:          sala.id,
      }
    }
  end

  describe 'GET /reglas_ambientales' do
    context 'admin' do
      before { sign_in_as(admin) }
      it 'returns 200' do
        get '/reglas_ambientales', headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'cultivador (forbidden — admin only)' do
      before { sign_in_as(cultivador) }
      it 'returns 403' do
        get '/reglas_ambientales', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'auditor (forbidden)' do
      before { sign_in_as(auditor) }
      it 'returns 403' do
        get '/reglas_ambientales', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'sin token' do
      it 'returns 401' do
        get '/reglas_ambientales'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /reglas_ambientales' do
    context 'admin' do
      before { sign_in_as(admin) }
      it 'creates regla and returns 201' do
        post '/reglas_ambientales', params: valid_params, headers: auth_headers, as: :json
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['nombre']).to eq('Temperatura alta')
      end
    end

    context 'cultivador (forbidden — must be 403 before validation)' do
      before { sign_in_as(cultivador) }
      it 'returns 403 without reaching validation' do
        post '/reglas_ambientales', params: valid_params, headers: auth_headers, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
