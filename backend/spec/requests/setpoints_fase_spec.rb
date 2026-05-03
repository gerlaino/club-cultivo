require 'rails_helper'

RSpec.describe 'SetpointsFase', type: :request do
  let(:club)       { create(:club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }
  let(:auditor)    { create(:user, :auditor, club: club) }

  let(:valid_params) do
    {
      setpoint_fase: {
        fase:         'vegetativo',
        tipo_lectura: 'temperatura',
        valor_min:    20.0,
        valor_max:    28.0,
        valor_ideal: 24.0,
      }
    }
  end

  describe 'GET /setpoints_fase' do
    context 'cultivador (read OK)' do
      before { sign_in_as(cultivador) }
      it 'returns 200' do
        get '/setpoints_fase', headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'admin' do
      before { sign_in_as(admin) }
      it 'returns 200' do
        get '/setpoints_fase', headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'auditor (forbidden)' do
      before { sign_in_as(auditor) }
      it 'returns 403' do
        get '/setpoints_fase', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /setpoints_fase' do
    context 'admin' do
      before { sign_in_as(admin) }
      it 'creates setpoint and returns 201' do
        post '/setpoints_fase', params: valid_params, headers: auth_headers, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    context 'cultivador (forbidden — must be 403 before validation)' do
      before { sign_in_as(cultivador) }
      it 'returns 403 without reaching validation' do
        post '/setpoints_fase', params: valid_params, headers: auth_headers, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'sin token' do
      it 'returns 401' do
        post '/setpoints_fase', params: valid_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /setpoints_fase/:id' do
    let!(:setpoint) do
      SetpointFase.create!(
        club_id:      club.id,
        fase:         'vegetativo',
        tipo_lectura: 'temperatura',
        valor_min:    20.0,
        valor_max:    28.0,
        valor_ideal: 24.0,
      )
    end

    context 'cultivador (forbidden)' do
      before { sign_in_as(cultivador) }
      it 'returns 403' do
        delete "/setpoints_fase/#{setpoint.id}", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
