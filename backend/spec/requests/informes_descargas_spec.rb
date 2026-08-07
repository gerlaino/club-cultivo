require 'rails_helper'

# AC: un informe que se presenta ante un auditor no puede ser una captura de pantalla. Seis
# de los siete generaban su PDF con html2canvas —una foto JPEG de la página, sin texto
# seleccionable ni buscable— y ninguno tenía Excel. Germán: "hay que rediseñar los formatos
# de todos los informes que se pueden descargar, que armen bien los cuadros".
RSpec.describe 'Informes — descargas', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:sala)  { create(:sala, sede: sede, club: club, kind: 'mixta') }

  before { sign_in_as(admin) }

  INFORMES = %w[reprocann produccion dispensaciones sedes cumplimiento plan_vs_real inase].freeze

  # Datos mínimos para que cada informe tenga algo que mostrar.
  before do
    p = create(:paciente, club: club, created_by: admin,
               reprocann_numero: 'R-1', reprocann_vencimiento: 6.months.from_now.to_date)
    lote = create(:lote, club: club, sala: sala, estado: 'floracion', rendimiento_objetivo_g: 500)
    create(:plant, lote: lote, club: club, state: 'floracion')
    create(:genetica, club: club, nombre: 'Cepa A', registrada_inase: true)
    stock = create(:stock, club: club, sede: sede, cantidad: 500)
    Dispensacion.create!(paciente: p, user: admin, stock: stock, cantidad: 10,
                         fecha_dispensacion: Time.zone.today)
  end

  INFORMES.each do |informe|
    describe "GET /informes/#{informe}" do
      it 'devuelve un PDF de verdad, no una imagen' do
        get "/api/informes/#{informe}.pdf"

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/pdf')
        expect(response.body[0, 4]).to eq('%PDF')
        # Un PDF armado con Prawn lleva fuentes embebidas; una captura de pantalla es una
        # sola imagen y no tiene ninguna.
        expect(response.body).to include('/Font')
      end

      it 'devuelve un Excel' do
        get "/api/informes/#{informe}.xlsx"

        expect(response).to have_http_status(:ok)
        expect(response.body[0, 2]).to eq('PK')
      end

      it 'sigue devolviendo JSON para la pantalla' do
        get "/api/informes/#{informe}"

        expect(response).to have_http_status(:ok)
        expect { JSON.parse(response.body) }.not_to raise_error
      end
    end
  end

  # Un club recién creado abre un informe antes de tener datos: no puede explotar.
  describe 'sin datos' do
    let(:club_vacio)  { create(:club) }
    let(:admin_vacio) { create(:user, :admin, club: club_vacio) }

    it 'genera igual el PDF, diciendo que no hay datos' do
      sign_in_as(admin_vacio)

      get '/api/informes/dispensaciones.pdf'

      expect(response).to have_http_status(:ok)
      expect(response.body[0, 4]).to eq('%PDF')
    end
  end

  it 'el auditor puede descargarlos (es su trabajo)' do
    sign_in_as(create(:user, :auditor, club: club))

    get '/api/informes/produccion.pdf'

    expect(response).to have_http_status(:ok)
  end

  it 'un cultivador no' do
    sign_in_as(create(:user, :cultivador, club: club))

    get '/api/informes/produccion.pdf'

    expect(response).to have_http_status(:forbidden)
  end
end
