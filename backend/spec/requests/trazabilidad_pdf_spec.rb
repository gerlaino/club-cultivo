require 'rails_helper'
require 'pdf/inspector'

# El PDF de trazabilidad de un stock: lo primero que pide un auditor en una inspección.
#
# NO ES UN DOCUMENTO QUE SE PRESENTE por mesa de entradas, así que sale siempre. Si hay variedades
# sin acreditar ante el INASE lo DICE — y nombra sólo las de ESE frasco: avisar por una variedad
# que no lo tocó nunca es ruido que enseña a ignorar el recuadro.
#
# Se agrega porque en pantalla fallaba con "No se pudo generar el PDF. Reintentá en un momento."
# —un mensaje que invita a reintentar algo que no iba a andar nunca— y no había ningún spec que
# tocara este endpoint en formato PDF.
RSpec.describe 'PDF de trazabilidad de un stock', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'mixta') }
  let(:sala)  { ActsAsTenant.with_tenant(club) { create(:sala, club: club, sede: sede) } }

  # La del frasco, y otra que no tiene nada que ver con él.
  let(:del_frasco) { ActsAsTenant.with_tenant(club) { create(:genetica, club: club, nombre: 'Amnesia Haze', registrada_inase: false) } }
  let!(:ajena)     { ActsAsTenant.with_tenant(club) { create(:genetica, club: club, nombre: 'Banana Punch', registrada_inase: false) } }

  let(:lote) { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: sala, sede: sede, genetica: del_frasco) } }
  let(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, genetica: del_frasco,
                     forma_producto: 'flor_seca', unidad: 'g', cantidad: 921,
                     estado: 'asignado', disponibilidad: 'ambas',
                     precio_sugerido_ars: 1_000, fecha_elaboracion: Time.zone.today - 10)
    end
  end

  let!(:inscripta) do
    ActsAsTenant.without_tenant do
      Genetica.create!(nombre: 'ANANDA001', global: true, club_id: nil,
                       registrada_inase: true, numero_registro_inase: 'INASE-12345')
    end
  end

  def texto_pdf = PDF::Inspector::Text.analyze(response.body).strings.join(' ')

  before { sign_in_as(admin) }

  it 'la pantalla se abre' do
    get "/api/stocks/#{stock.id}/trazabilidad"

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['stock']).to be_present
  end

  describe 'con la variedad del frasco sin declarar' do
    it 'el PDF SALE igual: la app no es un canal oficial' do
      get "/api/stocks/#{stock.id}/trazabilidad.pdf"

      expect(response).to have_http_status(:ok)
      expect(response.body.byteslice(0, 4)).to eq('%PDF')
    end

    it 'y lo dice en el papel, nombrando la variedad' do
      get "/api/stocks/#{stock.id}/trazabilidad.pdf"

      expect(texto_pdf).to include('sin acreditar ante el INASE')
      expect(texto_pdf).to include('Amnesia Haze')
    end

    # El punto de acotar: la organización tiene otras variedades sin declarar, y ninguna aparece
    # en este frasco. Nombrarlas acá sería hablar de otra cosa.
    it 'NO nombra variedades que no están en esta cadena' do
      get "/api/stocks/#{stock.id}/trazabilidad.pdf"

      expect(texto_pdf).not_to include('Banana Punch')
    end

    it 'tampoco frena si se pide "para presentar": este informe no se presenta' do
      get "/api/stocks/#{stock.id}/trazabilidad.pdf", params: { para_presentar: '1' }

      expect(response).to have_http_status(:ok)
    end
  end

  context 'con la variedad del frasco declarada' do
    before { del_frasco.update!(declarada_como: inscripta) }

    it 'el PDF sale sin salvedad, aunque la organización tenga otras sin declarar' do
      get "/api/stocks/#{stock.id}/trazabilidad.pdf"

      expect(response).to have_http_status(:ok)
      expect(texto_pdf).not_to include('sin acreditar ante el INASE')
    end
  end
end
