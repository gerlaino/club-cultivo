require 'rails_helper'

# Un informe que se PRESENTA ante el organismo no puede nombrar variedades que el club no
# puede acreditar. Pero el bloqueo va en la DESCARGA, no en la pantalla: el informe INASE en
# pantalla es justamente el que lista qué falta declarar — bloquearlo dejaría al club sin
# poder ver su propio problema, y con veintipico de pendientes nunca podría destrabarse.
RSpec.describe 'Guard: no se descargan informes con variedades sin declarar', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  let!(:inscripta) do
    ActsAsTenant.without_tenant do
      Genetica.create!(nombre: 'ANANDA001', global: true, club_id: nil,
                       registrada_inase: true, numero_registro_inase: 'INASE-12345')
    end
  end

  let!(:pendiente) { create(:genetica, club: club, nombre: 'Critical Kush', registrada_inase: false) }

  before { sign_in_as(admin) }

  describe 'con genéticas sin declarar' do
    it 'la PANTALLA del informe INASE se abre igual: es la que lista los pendientes' do
      get '/api/informes/inase'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['pendientes'].size).to eq(1)
    end

    it 'el PDF del informe INASE se niega, y dice cuáles faltan' do
      get '/api/informes/inase.pdf'

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['requiere_declaracion_inase']).to be(true)
      expect(body['geneticas_sin_declarar']).to include('Critical Kush')
    end

    it 'el Excel del informe INASE también se niega' do
      get '/api/informes/inase.xlsx'

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'el PDF del informe semestral se niega: es el que se presenta ante la autoridad' do
      get '/api/informe_semestral.pdf'

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['requiere_declaracion_inase']).to be(true)
    end

    # Los informes que no se presentan ante el organismo no tienen por qué trabarse.
    it 'el PDF de producción se descarga normalmente' do
      get '/api/informes/produccion.pdf'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'cuando todo está declarado' do
    before { pendiente.update!(declarada_como: inscripta) }

    it 'el PDF del informe INASE sale' do
      get '/api/informes/inase.pdf'

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/pdf')
    end

    it 'el Excel sale' do
      get '/api/informes/inase.xlsx'

      expect(response).to have_http_status(:ok)
    end
  end

  # Una variedad inscripta no necesita declararse: no puede trabar la descarga.
  describe 'un club cuyas genéticas están todas inscriptas' do
    before { pendiente.update!(registrada_inase: true, numero_registro_inase: 'INASE-999') }

    it 'descarga sin problema' do
      get '/api/informes/inase.pdf'

      expect(response).to have_http_status(:ok)
    end
  end
end
