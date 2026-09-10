require 'rails_helper'

# LA DESCARGA NO SE BLOQUEA. La app no es un canal oficial: nada de lo que se baja se presenta
# solo, así que negarle la descarga a la organización la dejaba sin poder ver su propia realidad,
# con un cartel que encima invitaba a reintentar algo que no iba a andar nunca.
#
# Son DOS caminos y la diferencia la pide quien descarga (`para_presentar`):
#   · normal         → sale siempre, con una SALVEDAD arriba nombrando qué no se puede acreditar
#   · para presentar → valida; si falta algo no sale y dice qué
RSpec.describe 'Informes con variedades sin declarar ante el INASE', type: :request do
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

  describe 'con genéticas sin declarar, descargando para MIRAR' do
    it 'la PANTALLA del informe INASE se abre: es la que lista los pendientes' do
      get '/api/informes/inase'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['pendientes'].size).to eq(1)
    end

    it 'el PDF del informe INASE SALE' do
      get '/api/informes/inase.pdf'

      expect(response).to have_http_status(:ok)
      expect(response.body.byteslice(0, 4)).to eq('%PDF')
    end

    it 'el Excel del informe INASE sale' do
      get '/api/informes/inase.xlsx'

      expect(response).to have_http_status(:ok)
    end

    it 'el PDF del informe semestral sale' do
      get '/api/informe_semestral.pdf'

      expect(response).to have_http_status(:ok)
    end

    it 'el PDF de REPROCANN sale' do
      get '/api/informes/reprocann.pdf'

      expect(response).to have_http_status(:ok)
    end

    # Los informes que no se presentan ante el organismo nunca tuvieron por qué trabarse.
    it 'el PDF de producción se descarga normalmente' do
      get '/api/informes/produccion.pdf'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'con genéticas sin declarar, PARA PRESENTAR' do
    it 'el PDF del informe INASE se niega, y dice cuáles faltan' do
      get '/api/informes/inase.pdf', params: { para_presentar: '1' }

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['requiere_declaracion_inase']).to be(true)
      expect(body['geneticas_sin_declarar']).to include('Critical Kush')
    end

    it 'el Excel del informe INASE también se niega' do
      get '/api/informes/inase.xlsx', params: { para_presentar: '1' }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'el semestral se niega: es EL documento que se presenta ante la autoridad' do
      get '/api/informe_semestral.pdf', params: { para_presentar: '1' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['requiere_declaracion_inase']).to be(true)
    end

    it 'REPROCANN se niega' do
      get '/api/informes/reprocann.pdf', params: { para_presentar: '1' }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    # Producción no se presenta ante nadie: la marca no le aplica.
    it 'producción se descarga igual aunque se pida para presentar' do
      get '/api/informes/produccion.pdf', params: { para_presentar: '1' }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'cuando todo está declarado' do
    before { pendiente.update!(declarada_como: inscripta) }

    it 'el PDF del informe INASE sale, también para presentar' do
      get '/api/informes/inase.pdf', params: { para_presentar: '1' }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/pdf')
    end

    it 'el Excel sale' do
      get '/api/informes/inase.xlsx', params: { para_presentar: '1' }

      expect(response).to have_http_status(:ok)
    end
  end

  # Una variedad inscripta no necesita declararse: no puede trabar la descarga.
  describe 'un club cuyas genéticas están todas inscriptas' do
    before { pendiente.update!(registrada_inase: true, numero_registro_inase: 'INASE-999') }

    it 'descarga sin problema, también para presentar' do
      get '/api/informes/inase.pdf', params: { para_presentar: '1' }

      expect(response).to have_http_status(:ok)
    end
  end
end
