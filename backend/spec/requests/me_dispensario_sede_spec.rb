require 'rails_helper'

# CUÁL ES "SU" MOSTRADOR, para el que atiende.
#
# `/me` se lo dice a la PWA para no pedir el listado de sedes entero en la pantalla que más se
# abre (la tarjeta de caja, arriba del buscador de pacientes). El mostrador vive en las sedes que
# ATIENDEN —`social` y `mixta`—: una organización que además cultiva tiene sedes de producción, y
# devolver una de esas como su mostrador termina en "no se pudo cargar el mostrador" sin decir por
# qué, y sin forma de arreglarlo desde la pantalla.
RSpec.describe 'GET /me — la sede de mostrador del dispensador', type: :request do
  include AuthHelpers

  let(:club) { create(:club) }
  let(:ana)  { create(:user, :dispensador, club: club) }

  let!(:cultivo)  { create(:sede, club: club, tipo: 'produccion', nombre: 'Vivero') }
  let!(:atiende)  { create(:sede, club: club, tipo: 'social',     nombre: 'Central') }

  def dispensario_sede
    sign_in_as(ana)
    get '/api/me', headers: auth_headers
    JSON.parse(response.body)['dispensario_sede']
  end

  it 'con las dos asignadas, devuelve la que atiende' do
    ana.sedes_asignadas << cultivo
    ana.sedes_asignadas << atiende

    expect(dispensario_sede['nombre']).to eq('Central')
  end

  # El caso que mordía: la lista de asignadas no está ordenada por nada en particular, así que
  # alcanzaba con que la de producción cayera primera.
  it 'con SÓLO una de producción asignada, no la devuelve: cae a la que atiende' do
    ana.sedes_asignadas << cultivo

    expect(dispensario_sede['nombre']).to eq('Central')
  end

  it 'sin sedes asignadas, la primera que atienda del club' do
    expect(dispensario_sede['nombre']).to eq('Central')
  end

  it 'si la organización no tiene ninguna sede que atienda, no inventa una' do
    atiende.destroy

    expect(dispensario_sede).to be_nil
  end
end
