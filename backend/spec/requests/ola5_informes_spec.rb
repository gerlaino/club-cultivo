require 'rails_helper'

RSpec.describe 'Ola 5 — Informes (auditor)', type: :request do
  let(:club)    { create(:club) }
  let(:admin)   { create(:user, :admin,   club: club) }
  let(:auditor) { create(:user, :auditor, club: club) }
  let(:medico)  { create(:user, :medico,  club: club) }

  let!(:sede)  { create(:sede, club: club, created_by: admin) }
  let!(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }

  INFORMES_ENDPOINTS = %w[reprocann produccion dispensaciones sedes cumplimiento].freeze

  context 'auditor' do
    before { sign_in_as(auditor) }

    INFORMES_ENDPOINTS.each do |endpoint|
      it "GET /informes/#{endpoint} → 200" do
        get "/informes/#{endpoint}", headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    it 'GET /informes/reprocann devuelve estructura correcta' do
      get '/informes/reprocann', headers: auth_headers
      body = JSON.parse(response.body)
      expect(body.keys).to include('total_pacientes', 'con_reprocann_vigente', 'lista_anonimizada')
    end

    it 'GET /informes/reprocann lista_anonimizada no contiene nombres completos' do
      create(:paciente, club: club, created_by: admin, nombre: 'Néstor', apellido: 'Cruz')
      get '/informes/reprocann', headers: auth_headers
      body = JSON.parse(response.body)
      lista = body['lista_anonimizada']
      nombres_completos = lista.map { |p| p['nombre'] }.compact
      expect(nombres_completos).to be_empty
      iniciales = lista.map { |p| p['iniciales'] }.compact
      expect(iniciales).not_to include('Néstor Cruz')
    end

    it 'GET /informes/produccion devuelve métricas de lotes' do
      get '/informes/produccion', headers: auth_headers
      body = JSON.parse(response.body)
      expect(body.keys).to include('total_lotes', 'lotes_activos', 'gramos_producidos')
    end

    it 'GET /informes/dispensaciones devuelve métricas sin nombres' do
      get '/informes/dispensaciones', headers: auth_headers
      body = JSON.parse(response.body)
      expect(body.keys).to include('total_dispensaciones', 'pacientes_atendidos')
      expect(body.keys).not_to include('pacientes')
    end

    it 'GET /informes/cumplimiento devuelve alertas regulatorias' do
      get '/informes/cumplimiento', headers: auth_headers
      body = JSON.parse(response.body)
      expect(body.keys).to include('pacientes_con_reprocann_vigente', 'tasa_cumplimiento', 'alertas')
    end
  end

  context 'admin' do
    before { sign_in_as(admin) }

    INFORMES_ENDPOINTS.each do |endpoint|
      it "GET /informes/#{endpoint} → 200 (admin también puede ver)" do
        get "/informes/#{endpoint}", headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end
  end

  context 'médico' do
    before { sign_in_as(medico) }

    it 'GET /informes/reprocann → 403' do
      get '/informes/reprocann', headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
