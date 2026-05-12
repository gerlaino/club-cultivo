require 'rails_helper'

RSpec.describe 'Export CSV', type: :request do
  let(:club)   { create(:club) }
  let(:sede)   { create(:sede, club: club) }
  let(:admin)  { create(:user, :admin,  club: club) }
  let(:medico) { create(:user, :medico, club: club) }
  let(:disp)   { create(:user, :dispensador, club: club) }

  describe 'GET /api/pacientes/export_csv' do
    before { create(:paciente, club: club) }

    context 'admin' do
      before { sign_in_as(admin) }

      it 'devuelve CSV con status 200' do
        get '/api/pacientes/export_csv', headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/csv')
      end

      it 'incluye cabecera con columnas esperadas' do
        get '/api/pacientes/export_csv', headers: auth_headers
        body = response.body.gsub("\xEF\xBB\xBF", '')
        header = body.lines.first
        expect(header).to include('Apellido', 'DNI', 'REPROCANN')
      end
    end

    context 'médico' do
      before { sign_in_as(medico) }

      it 'devuelve 200' do
        get '/api/pacientes/export_csv', headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'dispensador — no autorizado para export' do
      before { sign_in_as(disp) }

      it 'devuelve 403' do
        get '/api/pacientes/export_csv', headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/dispensaciones/export_csv' do
    context 'admin' do
      before { sign_in_as(admin) }

      it 'devuelve CSV' do
        get '/api/dispensaciones/export_csv', headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/csv')
      end

      it 'acepta filtro de fechas' do
        get '/api/dispensaciones/export_csv',
            params: { desde: '2026-01-01', hasta: '2026-12-31' },
            headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'dispensador' do
      before { sign_in_as(disp) }

      it 'devuelve 200' do
        get '/api/dispensaciones/export_csv', headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
