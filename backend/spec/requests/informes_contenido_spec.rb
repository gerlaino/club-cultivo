require 'rails_helper'
require 'pdf/inspector'

# Los specs de descarga verifican que el archivo SEA un PDF. Esto verifica que además DIGA lo
# que tiene que decir: que los números del documento coincidan con los de la pantalla, que
# nada quede fuera de la caja, y que un club sin datos no reciba una hoja muda.
RSpec.describe 'Informes — contenido de los archivos', type: :request do
  let(:club)  { create(:club, name: 'Club Verde') }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion', nombre: 'Sede Centro') }
  let(:sala)  { create(:sala, sede: sede, club: club, kind: 'mixta') }

  before { sign_in_as(admin) }

  # Sólo devuelve el CUERPO del documento: el encabezado y el membrete van en un repeater con
  # fuentes serif/mono que PDF::Inspector no decodifica (en el archivo están y se ven).
  def texto_pdf = PDF::Inspector::Text.analyze(response.body).strings.join(' ')
  def json_de(path)
    get "/api/informes/#{path}"
    JSON.parse(response.body)
  end

  describe 'informe de dispensaciones' do
    before do
      p = create(:paciente, club: club, created_by: admin, nombre: 'Ana', apellido: 'Gómez')
      stock = create(:stock, club: club, sede: sede, cantidad: 1000)
      Dispensacion.create!(paciente: p, user: admin, stock: stock, cantidad: 25,
                           fecha_dispensacion: Time.zone.today)
    end

    # LA propiedad que una captura de pantalla no tiene: el texto se puede buscar y copiar.
    # Se verifica sobre el PDF crudo porque PDF::Inspector no decodifica el encabezado
    # (va en un repeater con fuentes serif/mono), aunque en el archivo esté y se vea.
    it 'el texto se puede buscar y copiar, no es una imagen' do
      get '/api/informes/dispensaciones.pdf'

      expect(response.body).to include('/FontFile2')  # fuentes embebidas
      expect(response.body).to include('/ToUnicode')  # mapa que hace el texto buscable
      expect(response.body).not_to include('/DCTDecode') # sin JPEG de por medio
    end

    # Si el PDF y la pantalla dicen números distintos, el informe no sirve para nada.
    it 'los números del PDF son los mismos que los de la pantalla' do
      datos = json_de('dispensaciones')
      get '/api/informes/dispensaciones.pdf'

      expect(texto_pdf).to include(datos['total_dispensaciones'].to_s)
      expect(texto_pdf).to include('25')  # los gramos dispensados
    end

    # Antes salía "A.G." con la nota "el informe no expone datos personales". No protegía a
    # nadie —quien lo abre ya ve la ficha completa del paciente— y con dos pacientes de
    # iniciales iguales la tabla no se podía leer ni cruzar con nada.
    it 'nombra al paciente completo, y avisa que el informe es sensible' do
      get '/api/informes/dispensaciones.pdf'
      t = texto_pdf

      expect(t).to include('Gómez')
      expect(t).to match(/informaci[óo]n sensible/i)
    end
  end

  describe 'informe de sedes' do
    before { create(:plant, lote: create(:lote, club: club, sala: sala, estado: 'vegetativo'), club: club) }

    it 'nombra cada sede en la tabla' do
      get '/api/informes/sedes.pdf'

      expect(texto_pdf).to include('Sede Centro')
    end
  end

  describe 'un club sin datos' do
    it 'el PDF lo dice en vez de mostrar una tabla vacía' do
      get '/api/informes/dispensaciones.pdf'

      expect(texto_pdf).to match(/Sin datos/i)
    end
  end

  describe 'informe semestral' do
    before do
      create(:paciente, club: club, created_by: admin, nombre: 'Beto', apellido: 'Ruiz',
             reprocann_numero: 'RP-123', reprocann_vencimiento: 6.months.from_now.to_date)
    end

    # Este NO se anonimiza a propósito: se presenta ante la autoridad, que necesita
    # identificar a cada paciente.
    it 'lista la nómina con nombre y número de REPROCANN' do
      get '/api/informe_semestral.pdf'

      expect(response).to have_http_status(:ok)
      t = texto_pdf
      expect(t).to include('Beto Ruiz')
      expect(t).to include('RP-123')
    end

    it 'identifica al establecimiento' do
      get '/api/informe_semestral.pdf'

      expect(texto_pdf).to include('Club Verde')
    end

    it 'también sale en Excel' do
      get '/api/informe_semestral.xlsx'

      expect(response.body[0, 2]).to eq('PK')
    end
  end

  describe 'P&L de producción' do
    it 'genera PDF y Excel' do
      get '/api/analytics/contabilidad.pdf'
      expect(response.body[0, 4]).to eq('%PDF')

      get '/api/analytics/contabilidad.xlsx'
      expect(response.body[0, 2]).to eq('PK')
    end

    it 'aclara que la proyección no es dinero realizado' do
      get '/api/analytics/contabilidad.pdf'

      expect(texto_pdf).to match(/no es dinero realizado/i)
    end
  end

  # Una tabla con muchas filas es donde un PDF mal armado se rompe: se corta, se superpone o
  # tira CannotFit. Con 120 pacientes tiene que paginar solo.
  describe 'con muchas filas' do
    before do
      stock = create(:stock, club: club, sede: sede, cantidad: 100_000)
      120.times do |i|
        p = create(:paciente, club: club, created_by: admin, nombre: "P#{i}", apellido: "Ap#{i}")
        Dispensacion.create!(paciente: p, user: admin, stock: stock, cantidad: 1,
                             fecha_dispensacion: Time.zone.today)
      end
    end

    it 'pagina sin romperse' do
      get '/api/informes/dispensaciones.pdf'

      expect(response).to have_http_status(:ok)
      expect(PDF::Inspector::Page.analyze(response.body).pages.size).to be > 1
    end
  end
end
