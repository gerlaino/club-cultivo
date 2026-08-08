require 'rails_helper'

# El informe INASE se presenta ante el organismo: tiene que nombrar la variedad con la que el
# club acredita, no el nombre de fantasía con el que la cultiva. Y tiene que dejar en claro
# qué queda sin acreditar, que es lo único accionable del informe.
RSpec.describe 'Informe INASE con variedades declaradas', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  let!(:inscripta) do
    ActsAsTenant.without_tenant do
      Genetica.create!(nombre: 'ANANDA001', global: true, club_id: nil,
                       registrada_inase: true, numero_registro_inase: 'INASE-12345')
    end
  end

  let!(:declarada) do
    create(:genetica, club: club, nombre: 'Northern Lights',
                      registrada_inase: false, declarada_como: inscripta)
  end

  let!(:pendiente) do
    create(:genetica, club: club, nombre: 'Critical Kush', registrada_inase: false)
  end

  before { sign_in_as(admin) }

  def informe
    get '/api/informes/inase'
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body)
  end

  it 'nombra la variedad declarada con la inscripta, y guarda el nombre real aparte' do
    fila = informe['geneticas'].find { |g| g['nombre_propio'] == 'Northern Lights' }

    expect(fila['nombre']).to eq('ANANDA001')
    expect(fila['numero_registro_inase']).to eq('INASE-12345')
    expect(fila['declarada']).to be(true)
    expect(fila['acreditada']).to be(true)
  end

  it 'la que no declara nada sigue con su nombre y queda sin acreditar' do
    fila = informe['geneticas'].find { |g| g['nombre_propio'] == 'Critical Kush' }

    expect(fila['nombre']).to eq('Critical Kush')
    expect(fila['numero_registro_inase']).to be_nil
    expect(fila['acreditada']).to be(false)
  end

  it 'cuenta declaradas e inscriptas por separado, y sólo lo no acreditado como pendiente' do
    datos = informe

    expect(datos['declaradas']).to eq(1)
    expect(datos['sin_registrar']).to eq(1)
    expect(datos['pendientes'].map { |g| g['nombre_propio'] }).to eq(['Critical Kush'])
  end

  it 'declarar una genética la saca de los pendientes' do
    expect(informe['sin_registrar']).to eq(1)

    pendiente.update!(declarada_como: inscripta)

    expect(informe['sin_registrar']).to eq(0)
    expect(informe['pendientes']).to be_empty
    expect(informe['declaradas']).to eq(2)
  end
end
