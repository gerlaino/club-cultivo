require 'rails_helper'

# EL DNI VA COMPLETO EN LO QUE SE DESCARGA Y PARCIAL EN LA PANTALLA.
#
# Son dos usos distintos. La pantalla la mira cualquiera que pase por atrás, y con los últimos
# tres alcanza para desambiguar homónimos. El PDF y el Excel se PRESENTAN —ante el organismo, un
# auditor, un abogado— y un padrón con el documento tapado no acredita a nadie.
#
# Y el dato completo NO viaja en el JSON: si viajara, estaría en el navegador de cualquiera que
# abra el informe, se muestre o no en pantalla. Se agrega recién al armar el archivo.
RSpec.describe 'El DNI en los informes', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:paciente) do
    ActsAsTenant.with_tenant(club) do
      create(:paciente, club: club, nombre: 'Juana', apellido: 'Pérez', dni: '30111222',
                        reprocann_estado: 'vigente', reprocann_numero: 'RP-1',
                        reprocann_vencimiento: 6.months.from_now.to_date)
    end
  end

  def informe(ruta, formato = nil)
    sign_in_as(admin)
    get "/api/informes/#{ruta}#{formato ? ".#{formato}" : ''}", headers: auth_headers
    formato ? response.body : JSON.parse(response.body)
  end

  describe 'REPROCANN' do
    it 'en pantalla, sólo los últimos tres' do
      p = informe('reprocann')['lista_anonimizada'].first

      expect(p['dni_ultimos_3']).to eq('222')
      # Lo importante: el completo NI SIQUIERA VIAJA. No alcanza con no mostrarlo.
      expect(p).not_to have_key('dni')
      expect(response.body).not_to include('30111222')
    end

    it 'en el Excel, completo' do
      xlsx = informe('reprocann', 'xlsx')

      expect(response).to have_http_status(:ok)
      expect(xlsx).to be_present
      # El .xlsx es un zip: el texto va en la tabla de cadenas compartidas.
      expect(contenido_xlsx(xlsx)).to include('30111222')
    end

    it 'en el PDF, completo' do
      pdf = informe('reprocann', 'pdf')

      expect(response).to have_http_status(:ok)
      expect(pdf[0, 4]).to eq('%PDF')
      expect(texto_pdf(pdf)).to include('30111222')
    end
  end

  describe 'Dispensaciones' do
    before do
      ActsAsTenant.with_tenant(club) do
        stock = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                               unidad: 'g', cantidad: 500, estado: 'asignado',
                               disponibilidad: 'ambas', precio_sugerido_ars: 100)
        Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                             cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 500,
                             fecha_dispensacion: Time.zone.today)
      end
    end

    it 'en pantalla, sólo los últimos tres' do
      fila = informe('dispensaciones')['resumen_anonimizado'].first

      expect(fila['dni_ultimos_3']).to eq('222')
      expect(fila).not_to have_key('dni')
      expect(response.body).not_to include('30111222')
    end

    it 'en el Excel, completo' do
      expect(contenido_xlsx(informe('dispensaciones', 'xlsx'))).to include('30111222')
    end

    it 'en el PDF, completo' do
      expect(texto_pdf(informe('dispensaciones', 'pdf'))).to include('30111222')
    end
  end

  # Un .xlsx es un zip: el texto de las celdas vive en `sharedStrings.xml`.
  def contenido_xlsx(binario)
    require 'zip'
    texto = +''
    Zip::File.open_buffer(binario) { |zip| zip.each { |e| texto << e.get_input_stream.read if e.name.end_with?('.xml') } }
    texto
  rescue LoadError
    binario # sin rubyzip, se busca sobre el binario: el string igual aparece sin comprimir
  end

  # `pdf-inspector` ya está en el Gemfile del grupo de test: extraer el texto a mano no funciona
  # porque Prawn lo guarda comprimido y codificado por fuente.
  # Sin separador: Prawn parte una celda larga en varios fragmentos, y un DNI que se lee bien
  # igual aparecería como "301112" + "22". Lo que importa acá es que el dato esté completo; que
  # además NO se parta lo cubre el ancho de columna en `InformeDocument#anchos`.
  def texto_pdf(binario)
    require 'pdf/inspector'
    PDF::Inspector::Text.analyze(binario).strings.join
  end
end
