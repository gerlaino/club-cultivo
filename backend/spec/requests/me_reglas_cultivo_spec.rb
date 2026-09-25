require 'rails_helper'

# La tabla de "qué estado admite cada tipo de sala" estaba escrita DOS veces: acá
# (`Lote::KINDS_SALA_POR_ESTADO`, que es la que rechaza el alta) y hardcodeada en el modal del
# frontend. Mientras no coincidieron, la pantalla ofrecía "Enraizado" en una sala de floración y
# el alta moría con un 422 recién al apretar Crear.
#
# Ahora la manda el backend en /me. Va ahí y no en un endpoint aparte porque el router espera
# ese request antes de montar cualquier pantalla: la regla siempre llega antes que el formulario.
RSpec.describe 'GET /me — reglas de cultivo', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def reglas
    get '/me', headers: auth_headers
    JSON.parse(response.body).dig('reglas_cultivo', 'kinds_sala_por_estado')
  end

  before { sign_in_as(admin) }

  it 'viaja la tabla que usa el backend para validar, sin traducir' do
    expect(reglas).to eq(Lote::KINDS_SALA_POR_ESTADO.stringify_keys)
  end

  it 'dice que un lote en floración sólo entra en salas de floración o mixtas' do
    expect(reglas['floracion']).to match_array(%w[floracion mixta])
  end

  # Enraizado y vegetativo comparten fotoperíodo (18/6), así que comparten salas — incluidas las
  # de madres y clones, que son sub-tipos de vegetativo.
  it 'y que el que enraíza va donde el vegetativo' do
    expect(reglas['enraizado']).to eq(reglas['vegetativo'])
    expect(reglas['enraizado']).to include('madre', 'clon')
  end

  # Si alguien agrega un estado de cultivo y se olvida de la tabla, el frontend no tiene con qué
  # filtrar y vuelve a ofrecer combinaciones que el backend rechaza.
  it 'cubre todos los estados que exigen sala' do
    expect(reglas.keys).to match_array(Lote::CULTIVO_ESTADOS)
  end
end

# La misma tabla para una genética automática: la pantalla elige cuál usar según la genética
# y no escribe la excepción (21-sep-2026). Es la que valida el modelo y la que usa mover.
RSpec.describe 'GET /me — la tabla de salas de las automáticas', type: :request do
  include AuthHelpers
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  before { sign_in_as(admin); get '/me', headers: auth_headers }

  it 'viaja aparte, y en floración también vale la sala de vege' do
    tabla = JSON.parse(response.body).dig('reglas_cultivo', 'kinds_sala_por_estado_automatica')
    expect(tabla).to eq(Lote::KINDS_SALA_POR_ESTADO_AUTOMATICA.stringify_keys)
    expect(tabla['floracion']).to include('vegetativo', 'floracion', 'mixta')
    expect(tabla['vegetativo']).to eq(Lote::KINDS_SALA_POR_ESTADO['vegetativo'])
  end
end

# Dónde puede enraizar un lote (24-sep-2026): el desplegable ofrece la lista que valida el modelo.
RSpec.describe 'GET /me — métodos de enraizado', type: :request do
  include AuthHelpers
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  before { sign_in_as(admin); get '/me', headers: auth_headers }

  it 'viajan los mismos que acepta el lote' do
    expect(JSON.parse(response.body).dig('reglas_cultivo', 'metodos_enraizado')).to eq(Lote::METODOS_ENRAIZADO)
  end
end
