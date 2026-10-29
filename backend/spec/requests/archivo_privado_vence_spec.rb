require 'rails_helper'

# AC (29-oct-2026, seguridad tanda 2, FILES-01): el link a un archivo con datos de una persona (la
# constancia del REPROCANN, un comprobante, un adjunto del chat) vence. Dentro de la hora abre; después
# no, aunque se tenga el link. Las fotos de genéticas y lotes NO cambian (se muestran en páginas
# públicas y el service worker las guarda por URL).
RSpec.describe 'Links a archivos privados', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  def abrir(url)
    # El helper de specs le pone /api a todo lo que no empiece con http: se pide como el navegador,
    # al host del test (el link trae el de la app).
    get "http://www.example.com#{url.sub(%r{\Ahttps?://[^/]+}, "")}"
  end

  before do
    paciente.reprocann_documento.attach(io: StringIO.new('%PDF-fake'), filename: 'reprocann.pdf', content_type: 'application/pdf')
    sign_in_as(admin)
  end

  it 'la ficha da un link que abre dentro de la hora' do
    get "/pacientes/#{paciente.id}"
    url = response.parsed_body.dig('data', 'reprocann_documento_url') || response.parsed_body['reprocann_documento_url']
    expect(url).to be_present

    reset!
    abrir(url)
    expect(response).to have_http_status(:redirect)
  end

  it 'pasada la hora, el mismo link ya no abre (ni con sesión ni sin ella)' do
    get "/pacientes/#{paciente.id}"
    url = response.parsed_body.dig('data', 'reprocann_documento_url') || response.parsed_body['reprocann_documento_url']

    travel(Seguridad::ArchivoPrivado::VIGENCIA + 1.minute) do
      reset!
      abrir(url)
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'un link de antes (sin vencimiento) sigue siendo de otro formato: lo nuevo lleva vencimiento' do
    vieja = Rails.application.routes.url_helpers.rails_blob_path(paciente.reprocann_documento, only_path: true)
    nueva = Seguridad::ArchivoPrivado.ruta(paciente.reprocann_documento)

    expect(nueva).not_to eq(vieja)
  end

  it 'las fotos de una genética no vencen (las guarda el service worker por URL)' do
    genetica = ActsAsTenant.with_tenant(club) { create(:genetica, club: club) }
    genetica.fotos.attach(io: StringIO.new('img'), filename: 'g.jpg', content_type: 'image/jpeg')
    url = Rails.application.routes.url_helpers.rails_blob_path(genetica.fotos.first, only_path: true)

    travel(2.days) do
      abrir(url)
      expect(response).to have_http_status(:redirect)
    end
  end
end
