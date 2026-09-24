require 'rails_helper'

# LAS CATEGORÍAS DEL SISTEMA LAS NOMBRA EL SERVIDOR (24-sep-2026). La pantalla de Contabilidad tenía
# su propia copia de los nombres y se quedaba atrás: a «Devolución a paciente» y a las de la caja
# las mostraba con la clave cruda. Ahora el tablero manda la lista entera, de una sola fuente.
RSpec.describe 'Contabilidad — categorías del sistema en el tablero', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  before { sign_in_as(admin) }

  it 'vienen todas, con el nombre que se muestra' do
    get '/api/movimientos_contables/dashboard'

    expect(response).to have_http_status(:ok)
    lista = JSON.parse(response.body)['categorias_sistema'].to_h { |c| [c['value'], c['label']] }
    expect(lista.keys).to match_array(MovimientoContable::CATEGORIAS)
    expect(lista['envio']).to eq('Envíos')
    expect(lista['devolucion_paciente']).to eq('Devolución a paciente')
  end
end
