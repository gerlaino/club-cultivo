require 'rails_helper'
require 'zip'

# AC (11-oct-2026, plan aprobado por Germán): «Exportar todos mis datos» del autocultivo — un ZIP
# con los informes de todo el historial (PDF y Excel), las plantas, el diario y las fotos. Se arma
# en segundo plano y se baja SÓLO con sesión (son datos de salud), y sólo lo de la propia cuenta.
RSpec.describe 'Exportar mis datos (autocultivo)', type: :request do
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(ExportarDatosJob).to receive(:store).and_return(store)
    sign_in_as(admin)
  end

  def armar!
    ActsAsTenant.with_tenant(club) do
      sala = create(:sala, club: club)
      lote = create(:lote, club: club, sala: sala, estado: 'vegetativo', start_date: 10.days.ago.to_date)
      create(:plant, lote: lote, club: club, state: 'vegetativo', nombre: 'Mi planta')
      create(:registro_ambiental, lote: lote, club: club, ph: 6.1, ec: 1.2, registrado_en: 1.day.ago)
      LoteFoto.create!(club: club, lote: lote, tomada_el: 2.days.ago.to_date,
                       imagen: Rack::Test::UploadedFile.new(StringIO.new("\x89PNG\r\n\x1a\n"), 'image/png', original_filename: 'f.png'))
    end
  end

  it 'pedir la exportación la encola una vez y dice que se está armando' do
    expect { post '/mis_datos/exportar' }.to have_enqueued_job(ExportarDatosJob).exactly(:once)
    expect(json['estado']).to eq('armando')
    expect { post '/mis_datos/exportar' }.not_to have_enqueued_job(ExportarDatosJob)
  end

  it 'el ZIP trae los informes, las plantas, el diario y las fotos' do
    armar!
    ExportarDatosJob.perform_now(club.id, admin.id)

    get '/mis_datos/exportar'
    expect(json['estado']).to eq('listo')

    get '/mis_datos/exportar/descargar'
    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Type']).to include('application/zip')
    nombres = []
    Zip::File.open_buffer(StringIO.new(response.body)) { |z| z.each { |e| nombres << e.name } }
    expect(nombres).to include('LEEME.txt', 'informes/mi_cosecha.pdf', 'informes/mis_gastos.xlsx',
                               'mis_plantas.xlsx', 'diario.xlsx')
    expect(nombres.grep(%r{\Afotos/})).not_to be_empty
  end

  it 'sin exportación lista, descargar no devuelve nada' do
    get '/mis_datos/exportar/descargar'
    expect(response).to have_http_status(:not_found)
  end

  it 'una organización no lo tiene' do
    org = create(:club, plan: 'basico', features: { 'cultivo' => true })
    sign_in_as(create(:user, :admin, club: org))

    post '/mis_datos/exportar'
    expect(response).to have_http_status(:not_found)
  end

  it 'aislamiento: la exportación de otra cuenta no se baja desde esta' do
    otro = create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL)
    otro_admin = create(:user, :admin, club: otro)
    ExportarDatosJob.perform_now(otro.id, otro_admin.id)

    get '/mis_datos/exportar/descargar'
    expect(response).to have_http_status(:not_found)
  end
end
