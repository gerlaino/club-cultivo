require 'rails_helper'

RSpec.describe 'Informe REPROCANN en PDF', type: :request do
  let(:club)    { create(:club, name: 'Club Demo', cuit: '30-12345678-9') }
  let(:admin)   { create(:user, :admin,   club: club) }
  let(:auditor) { create(:user, :auditor, club: club) }

  before do
    create(:paciente, club: club, created_by: admin, nombre: 'Ana',  apellido: 'Gómez',
           reprocann_numero: 'RP-1', reprocann_vencimiento: 60.days.from_now)
    create(:paciente, club: club, created_by: admin, nombre: 'Luis', apellido: 'Díaz',
           reprocann_numero: 'RP-2', reprocann_vencimiento: 5.days.ago)
  end

  context 'admin' do
    before { sign_in_as(admin) }

    it 'GET /informes/reprocann.pdf devuelve un PDF válido' do
      get '/informes/reprocann.pdf', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/pdf')
      expect(response.body[0, 5]).to eq('%PDF-')
      expect(response.body.bytesize).to be > 1000
    end

    it 'la versión JSON sigue funcionando' do
      get '/informes/reprocann', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include('total_pacientes', 'lista_anonimizada')
    end

    it 'GET /informes/reprocann.xlsx devuelve un Excel válido' do
      get '/informes/reprocann.xlsx', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      # los .xlsx son archivos ZIP → empiezan con "PK"
      expect(response.body[0, 2]).to eq('PK')
    end
  end

  context 'auditor' do
    before { sign_in_as(auditor) }

    it 'puede descargar el PDF (solo lectura)' do
      get '/informes/reprocann.pdf', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/pdf')
    end
  end

  it 'sin autenticación no se puede' do
    get '/informes/reprocann.pdf'
    expect(response).to have_http_status(:unauthorized)
  end
end
