require 'rails_helper'

RSpec.describe 'Ola 5 — Documentos extendidos', type: :request do
  let(:club)    { create(:club) }
  let(:admin)   { create(:user, :admin,   club: club) }
  let(:medico)  { create(:user, :medico,  club: club) }
  let(:abogado) { create(:user, :abogado, club: club) }

  let(:paciente_con) { create(:paciente, club: club, created_by: admin, con_seguimiento_medico: true) }

  let!(:doc_clinico_con) do
    create(:documento, club: club, user: medico, subido_por: medico,
           tipo: 'reprocann', paciente: paciente_con)
  end
  let!(:doc_legal) do
    create(:documento, club: club, user: abogado, subido_por: abogado, tipo: 'contrato_socio')
  end
  let!(:doc_clinico_sin) do
    paciente_sin = create(:paciente, club: club, created_by: admin, con_seguimiento_medico: false)
    create(:documento, club: club, user: medico, subido_por: medico,
           tipo: 'reprocann', paciente: paciente_sin)
  end

  # ── Médico scope ────────────────────────────────────────────
  context 'médico GET /documentos' do
    before { sign_in_as(medico) }

    it 'devuelve solo documentos clínicos de pacientes con seguimiento' do
      get '/documentos', headers: auth_headers
      ids = JSON.parse(response.body).map { |d| d['id'] }
      expect(ids).to include(doc_clinico_con.id)
      expect(ids).not_to include(doc_legal.id)
      expect(ids).not_to include(doc_clinico_sin.id)
    end
  end

  # ── Abogado scope ───────────────────────────────────────────
  context 'abogado GET /documentos' do
    before { sign_in_as(abogado) }

    it 'solo ve sus propios documentos' do
      get '/documentos', headers: auth_headers
      ids = JSON.parse(response.body).map { |d| d['id'] }
      expect(ids).to include(doc_legal.id)
      expect(ids).not_to include(doc_clinico_con.id)
    end
  end

  # ── Admin ve todo ────────────────────────────────────────────
  context 'admin GET /documentos' do
    before { sign_in_as(admin) }

    it 've todos los documentos del club' do
      get '/documentos', headers: auth_headers
      ids = JSON.parse(response.body).map { |d| d['id'] }
      expect(ids).to include(doc_clinico_con.id, doc_legal.id, doc_clinico_sin.id)
    end
  end

  # ── Roles no autorizados ─────────────────────────────────────
  context 'dispensador GET /documentos' do
    before do
      dispensador = create(:user, :dispensador, club: club)
      sign_in_as(dispensador)
    end

    it 'devuelve 403' do
      get '/documentos', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ── Admin crea documento ─────────────────────────────────────
  context 'admin POST /documentos' do
    before { sign_in_as(admin) }

    it 'crea documento con categoría correcta' do
      post '/documentos',
           params: { documento: { tipo: 'estatuto', titulo: 'Estatuto 2026', estado: 'vigente' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['categoria']).to eq('legal')
    end
  end

  # ── Abogado crea documento legal ─────────────────────────────
  context 'abogado POST /documentos' do
    before { sign_in_as(abogado) }

    it 'crea documento legal correctamente' do
      post '/documentos',
           params: { documento: { tipo: 'acta_asamblea', titulo: 'Acta 2026', estado: 'vigente' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:created)
    end
  end
end
