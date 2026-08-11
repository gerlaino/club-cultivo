require 'rails_helper'

RSpec.describe 'Ola 5 — con_seguimiento_medico', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin,       club: club) }
  let(:medico)      { create(:user, :medico,       club: club) }
  let(:dispensador) { create(:user, :dispensador,  club: club) }

  let!(:paciente_con)    { create(:paciente, club: club, created_by: admin, con_seguimiento_medico: true) }
  let!(:paciente_sin)    { create(:paciente, club: club, created_by: admin, con_seguimiento_medico: false) }

  # ── Scope médico ────────────────────────────────────────────
  context 'médico GET /pacientes' do
    before { sign_in_as(medico) }

    it 'devuelve solo pacientes con seguimiento médico' do
      get '/pacientes', headers: auth_headers
      ids = JSON.parse(response.body)['data'].map { |p| p['id'] }
      expect(ids).to include(paciente_con.id)
      expect(ids).not_to include(paciente_sin.id)
    end
  end

  # ── Scope admin ─────────────────────────────────────────────
  context 'admin GET /pacientes' do
    before { sign_in_as(admin) }

    it 'devuelve todos los pacientes del club' do
      get '/pacientes', headers: auth_headers
      ids = JSON.parse(response.body)['data'].map { |p| p['id'] }
      expect(ids).to include(paciente_con.id, paciente_sin.id)
    end

    it 'filtro sin_seguimiento devuelve solo los sin seguimiento' do
      get '/pacientes', params: { sin_seguimiento: '1' }, headers: auth_headers
      ids = JSON.parse(response.body)['data'].map { |p| p['id'] }
      expect(ids).to include(paciente_sin.id)
      expect(ids).not_to include(paciente_con.id)
    end
  end

  # ── Médico crea paciente → con_seguimiento_medico=true ──────
  context 'médico POST /pacientes' do
    before { sign_in_as(medico) }

    it 'crea paciente con con_seguimiento_medico=true' do
      post '/pacientes',
           params: { paciente: { nombre: 'Mario', apellido: 'Perez', dni: '22111333', fecha_nacimiento: '1985-06-15' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['data']['con_seguimiento_medico']).to be true
    end
  end

  # ── Dispensador crea paciente → con_seguimiento_medico=false + alerta ──
  context 'dispensador POST /pacientes' do
    before { sign_in_as(dispensador) }

    it 'crea paciente con con_seguimiento_medico=false' do
      post '/pacientes',
           params: { paciente: { nombre: 'Juana', apellido: 'Ruiz', dni: '33222111', fecha_nacimiento: '1990-03-20' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['data']['con_seguimiento_medico']).to be false
    end

    # El aviso cambió de contenido y de destinatarios: antes era informativo ("creó un paciente
    # sin seguimiento médico") y sólo al admin. Ahora el alta del mostrador queda PENDIENTE DE
    # APROBACIÓN, así que el aviso describe algo que hay que hacer y va a los dos roles que
    # pueden hacerlo. Ver spec/requests/paciente_aprobacion_spec.rb.
    it 'avisa a quienes pueden aprobar el alta que hizo el dispensador' do
      expect {
        post '/pacientes',
             params: { paciente: { nombre: 'Pedro', apellido: 'Gil', dni: '44333222', fecha_nacimiento: '1988-08-10' } },
             headers: auth_headers, as: :json
      }.to change(AlertaInterna, :count).by(2)

      alertas = AlertaInterna.where(tipo: 'paciente_pendiente_aprobacion')
      expect(alertas.pluck(:destinada_a_role)).to match_array(%w[admin medico])
      expect(alertas.pluck(:club_id).uniq).to eq([club.id])
    end
  end

  # ── Dispensador no puede cambiar con_seguimiento_medico ──────
  context 'dispensador PATCH /pacientes/:id con con_seguimiento_medico' do
    before { sign_in_as(dispensador) }

    it 'devuelve 403 al intentar cambiar seguimiento médico' do
      patch "/pacientes/#{paciente_sin.id}",
            params: { paciente: { con_seguimiento_medico: true } },
            headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ── Admin puede cambiar con_seguimiento_medico ───────────────
  context 'admin PATCH /pacientes/:id' do
    before { sign_in_as(admin) }

    it 'puede cambiar con_seguimiento_medico a true' do
      patch "/pacientes/#{paciente_sin.id}",
            params: { paciente: { con_seguimiento_medico: true } },
            headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(paciente_sin.reload.con_seguimiento_medico).to be true
    end
  end
end
