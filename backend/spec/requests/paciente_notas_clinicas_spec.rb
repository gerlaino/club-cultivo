require 'rails_helper'

RSpec.describe 'Pacientes — notas_clinicas y timeline', type: :request do
  let(:club)         { create(:club) }
  let(:admin)        { create(:user, club: club, role: 'admin') }
  let(:medico)       { create(:user, club: club, role: 'medico') }
  let(:cultivador)   { create(:user, club: club, role: 'cultivador') }
  let(:dispensador)  { create(:user, club: club, role: 'dispensador') }
  let!(:paciente)    { create(:paciente, club: club, created_by: admin, notas_clinicas: 'Paciente con epilepsia refractaria') }

  describe 'GET /pacientes/:id — notas_clinicas' do
    context 'admin' do
      it 'incluye notas_clinicas en la respuesta' do
        sign_in_as(admin)
        get "/pacientes/#{paciente.id}", headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)['data']
        expect(data['notas_clinicas']).to eq('Paciente con epilepsia refractaria')
      end
    end

    context 'medico' do
      it 'incluye notas_clinicas' do
        sign_in_as(medico)
        get "/pacientes/#{paciente.id}", headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['notas_clinicas']).to be_present
      end
    end

    context 'cultivador' do
      it 'recibe 403 — cultivador no tiene acceso a pacientes' do
        sign_in_as(cultivador)
        get "/pacientes/#{paciente.id}", headers: auth_headers, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT /pacientes/:id — update notas_clinicas' do
    context 'admin' do
      it 'puede actualizar notas_clinicas' do
        sign_in_as(admin)
        put "/pacientes/#{paciente.id}", params: { paciente: { notas_clinicas: 'Actualizado' } }, headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(paciente.reload.notas_clinicas).to eq('Actualizado')
      end
    end

    context 'cultivador' do
      it 'recibe 403 al intentar actualizar notas_clinicas' do
        sign_in_as(cultivador)
        put "/pacientes/#{paciente.id}", params: { paciente: { notas_clinicas: 'Intento' } }, headers: auth_headers, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /pacientes/:id/timeline' do
    context 'admin' do
      it 'devuelve timeline con evento de alta' do
        sign_in_as(admin)
        get "/pacientes/#{paciente.id}/timeline", headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        timeline = JSON.parse(response.body)['timeline']
        expect(timeline).to be_an(Array)
        expect(timeline.any? { |e| e['tipo'] == 'alta' }).to be true
      end
    end

    context 'dispensador' do
      it 'recibe 403' do
        sign_in_as(dispensador)
        get "/pacientes/#{paciente.id}/timeline", headers: auth_headers, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'paciente de otro club' do
      let(:otro_club)  { create(:club) }
      let(:otro_admin) { create(:user, club: otro_club, role: 'admin') }

      it 'recibe 404 (no puede ver paciente de otro club)' do
        sign_in_as(otro_admin)
        get "/pacientes/#{paciente.id}/timeline", headers: auth_headers, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
