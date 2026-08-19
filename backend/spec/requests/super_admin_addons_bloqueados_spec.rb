require 'rails_helper'

# AC: hay add-ons que NO se pueden prender, ni para probar. Son los que no funcionan de verdad:
# WhatsApp sin la cuenta de Twilio de la plataforma, y ARICCAME que no le transmite nada al
# organismo. Prenderlos genera una expectativa que después hay que explicarle a un cliente.
#
# El candado NO puede vivir sólo en el toggle: el panel del super admin lo usan dos personas y la
# API se saltea la pantalla siempre.
RSpec.describe 'Add-ons bloqueados', type: :request do
  include AuthHelpers

  let(:club)        { create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => true }) }
  let(:super_admin) { create(:user, :super_admin, club: nil) }

  before { sign_in_as(super_admin) }

  def prender(clave, valor = true)
    patch "/api/super_admin/clubs/#{club.id}", params: { club: { features: { clave => valor } } }
  end

  Club::ADDONS_BLOQUEADOS.each_key do |clave|
    it "no prende #{clave} aunque se mande por la API" do
      prender(clave)

      expect(response).to have_http_status(:ok)
      expect(club.reload.feature?(clave)).to be(false)
      expect(club.features[clave]).not_to be(true)
    end
  end

  # Apagarlo sí se acepta —hay que poder limpiar una organización que lo tenga guardado— y sigue
  # el mismo camino que cualquier otra baja: se programa para el fin del período, no se corta hoy.
  it 'apagarlo se acepta y se programa como cualquier baja' do
    club.update!(features: club.features.merge('whatsapp' => true))

    prender('whatsapp', false)

    expect(response).to have_http_status(:ok)
    expect(club.reload.baja_programada?('whatsapp')).to be(true)
  end

  it 'la ficha dice cuáles están bloqueados y por qué, para no adivinar' do
    get "/api/super_admin/clubs/#{club.id}"

    addons = JSON.parse(response.body)['addons']
    whatsapp = addons.find { |a| a['clave'] == 'whatsapp' }
    expect(whatsapp['bloqueado']).to be(true)
    expect(whatsapp['motivo_bloqueo']).to be_present

    buffet = addons.find { |a| a['clave'] == 'bar' }
    expect(buffet['bloqueado']).to be(false), 'el Buffet se puede prender para probarlo'
    expect(buffet['incompleto']).to be(true), 'y tiene que avisar que está en construcción'
  end

  it 'cada adicional dice a qué pack le sirve, o que es transversal' do
    get '/api/super_admin/catalogo'

    addons = JSON.parse(response.body)['addons'].index_by { |a| a['clave'] }
    expect(addons['iot']['pack']).to eq('cultivo')
    expect(addons['bar']['pack']).to eq('produccion_dispensa')
    expect(addons['bar']['pack_label']).to eq('Producción y dispensa')
    expect(addons['chatbot']['pack']).to be_nil, 'el chatbot sirve a las dos suites'
  end
end
