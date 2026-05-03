require 'rails_helper'

RSpec.describe 'Pacientes — role authorization matrix', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, club: club, role: 'admin') }
  let(:medico)      { create(:user, club: club, role: 'medico') }
  let(:cultivador)  { create(:user, club: club, role: 'cultivador') }
  let(:manicura)    { create(:user, club: club, role: 'manicura') }
  let(:auditor)     { create(:user, club: club, role: 'auditor') }
  let(:dispensador) { create(:user, club: club, role: 'dispensador') }
  let(:delivery)    { create(:user, club: club, role: 'delivery') }
  let(:abogado)     { create(:user, club: club, role: 'abogado') }
  let!(:paciente)   { create(:paciente, club: club, created_by: admin, notas_clinicas: 'Historia confidencial') }

  # ── Bug 1: notas_clinicas persiste en DB ─────────────────────────────────────
  describe 'Bug 1 — notas_clinicas persistence' do
    context 'admin PATCH con notas_clinicas' do
      it 'persiste el valor en la base de datos y lo devuelve en GET' do
        sign_in_as(admin)

        put "/pacientes/#{paciente.id}",
            params: { paciente: { notas_clinicas: 'TEST_PERSIST', nombre: paciente.nombre, apellido: paciente.apellido, dni: paciente.dni, fecha_nacimiento: paciente.fecha_nacimiento } },
            headers: auth_headers, as: :json

        expect(response).to have_http_status(:ok)

        # Re-read from DB
        get "/pacientes/#{paciente.id}", headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['notas_clinicas']).to eq('TEST_PERSIST')

        # Confirm it's actually in the DB
        expect(paciente.reload.notas_clinicas).to eq('TEST_PERSIST')
      end
    end

    context 'medico PATCH con notas_clinicas' do
      it 'persiste correctamente' do
        sign_in_as(medico)
        put "/pacientes/#{paciente.id}",
            params: { paciente: { notas_clinicas: 'Nota medica', nombre: paciente.nombre, apellido: paciente.apellido, dni: paciente.dni, fecha_nacimiento: paciente.fecha_nacimiento } },
            headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(paciente.reload.notas_clinicas).to eq('Nota medica')
      end
    end

    context 'auditor PATCH con notas_clinicas' do
      it 'recibe 403 — no puede modificar notas clínicas' do
        sign_in_as(auditor)
        put "/pacientes/#{paciente.id}",
            params: { paciente: { notas_clinicas: 'Intento auditor', nombre: paciente.nombre, apellido: paciente.apellido, dni: paciente.dni, fecha_nacimiento: paciente.fecha_nacimiento } },
            headers: auth_headers, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(paciente.reload.notas_clinicas).to eq('Historia confidencial')
      end
    end
  end

  # ── Bug 2: timeline solo para admin+medico ────────────────────────────────────
  describe 'Bug 2 — GET /pacientes/:id/timeline authorization' do
    it 'admin 200' do
      sign_in_as(admin)
      get "/pacientes/#{paciente.id}/timeline", headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['timeline']).to be_an(Array)
    end

    it 'medico 200' do
      sign_in_as(medico)
      get "/pacientes/#{paciente.id}/timeline", headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'dispensador 403' do
      sign_in_as(dispensador)
      get "/pacientes/#{paciente.id}/timeline", headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'cultivador 403 (cultivador no ve pacientes en absoluto)' do
      sign_in_as(cultivador)
      get "/pacientes/#{paciente.id}/timeline", headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'manicura 403' do
      sign_in_as(manicura)
      get "/pacientes/#{paciente.id}/timeline", headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'auditor 403 — timeline es solo para el equipo clínico' do
      sign_in_as(auditor)
      get "/pacientes/#{paciente.id}/timeline", headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'abogado 403' do
      sign_in_as(abogado)
      get "/pacientes/#{paciente.id}/timeline", headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'delivery 403' do
      sign_in_as(delivery)
      get "/pacientes/#{paciente.id}/timeline", headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ── Decisión de policy: index y show por rol ─────────────────────────────────
  describe 'GET /pacientes — index' do
    it 'cultivador 403' do
      sign_in_as(cultivador)
      get '/pacientes', headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'manicura 403' do
      sign_in_as(manicura)
      get '/pacientes', headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'auditor 403 (Ola 5: usa /informes/reprocann)' do
      sign_in_as(auditor)
      get '/pacientes', headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'delivery 403 (ya existía)' do
      sign_in_as(delivery)
      get '/pacientes', headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'abogado 403 (ya existía)' do
      sign_in_as(abogado)
      get '/pacientes', headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /pacientes/:id — show' do
    it 'cultivador 403' do
      sign_in_as(cultivador)
      get "/pacientes/#{paciente.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'manicura 403' do
      sign_in_as(manicura)
      get "/pacientes/#{paciente.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'auditor 403 (Ola 5: usa /informes, no tiene acceso directo a pacientes)' do
      sign_in_as(auditor)
      get "/pacientes/#{paciente.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'dispensador 200 sin notas_clinicas' do
      sign_in_as(dispensador)
      get "/pacientes/#{paciente.id}", headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)['data']
      expect(data.key?('notas_clinicas')).to be false
    end
  end
end
