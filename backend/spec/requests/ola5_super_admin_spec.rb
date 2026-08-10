require 'rails_helper'

RSpec.describe 'Ola 5 — Super Admin', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:super_admin) { create(:user, :super_admin) }

  context 'GET /super_admin/clubs' do
    before { sign_in_as(super_admin) }

    it 'devuelve lista de clubes → 200' do
      club
      get '/super_admin/clubs', headers: auth_headers
      expect(response).to have_http_status(:ok)
    end
  end

  context 'GET /super_admin/metricas' do
    before { sign_in_as(super_admin) }

    it 'devuelve métricas globales → 200' do
      get '/super_admin/metricas', headers: auth_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.keys).to include('total_clubes', 'total_lotes_activos', 'mrr')
    end
  end

  # El modo observador está SUSPENDIDO (User::OBSERVADOR_HABILITADO). Estos tres contextos
  # describen el modo ANDANDO y vuelven solos cuando se reactive; el estado suspendido lo cubre
  # spec/requests/super_admin_observador_suspendido_spec.rb.
  context 'POST /super_admin/clubs/:id/observar' do
    before do
      skip 'modo observador suspendido' unless User::OBSERVADOR_HABILITADO
      sign_in_as(super_admin)
    end

    # Ya no devuelve un `token`: la respuesta pedía mandarlo en un header `X-Observer-Token`
    # que ningún controller leía nunca, así que era una sensación de seguridad y nada más. El
    # modo se activa por el estado de la sesión (ver User#modo_observador?).
    it 'devuelve el estado de la observación' do
      post "/super_admin/clubs/#{club.id}/observar", headers: auth_headers
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['observando']).to be(true)
      expect(body['club_id']).to eq(club.id)
      expect(body['solo_lectura']).to be(true)
    end

    it 'pone al super_admin en modo observador' do
      post "/super_admin/clubs/#{club.id}/observar", headers: auth_headers
      super_admin.reload
      expect(super_admin.observer_club_id).to eq(club.id)
      expect(super_admin.observer_expires_at).to be_future
    end
  end

  context 'DELETE /super_admin/clubs/:id/detener_observacion' do
    before do
      sign_in_as(super_admin)
      super_admin.update_columns(
        observer_club_id:    club.id,
        observer_token:      'sometoken',
        observer_expires_at: 15.minutes.from_now
      )
    end

    it 'limpia el modo observador' do
      delete "/super_admin/clubs/#{club.id}/detener_observacion", headers: auth_headers
      expect(response).to have_http_status(:no_content)
      super_admin.reload
      expect(super_admin.observer_club_id).to be_nil
    end
  end

  context 'modo observador bloquea escritura' do
    before do
      skip 'modo observador suspendido' unless User::OBSERVADOR_HABILITADO
      sign_in_as(super_admin)
      super_admin.update_columns(
        observer_club_id:    club.id,
        observer_token:      SecureRandom.hex(24),
        observer_expires_at: 15.minutes.from_now
      )
    end

    it 'POST a endpoint regulatorio → 403 con mensaje de observación' do
      post '/pacientes',
           params: { paciente: { nombre: 'Hack', apellido: 'Test', dni: '55566677', fecha_nacimiento: '1990-01-01' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']).to include('observación')
    end
  end

  context 'rol no super_admin es rechazado' do
    before { sign_in_as(admin) }

    it 'GET /super_admin/clubs → 403' do
      get '/super_admin/clubs', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
