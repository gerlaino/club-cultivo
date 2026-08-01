require 'rails_helper'

# El registro ambiental de una sala se reparte a sus lotes: todo lo que respira el aire del cuarto.
#
# MENOS los que están ENRAIZANDO. Antes sí los alcanzaba —se los había olvidado y se arregló—, pero
# resultó ser media verdad: el esqueje depende del aire, sí, pero del aire del PROPAGADOR, no del
# cuarto (la sala marca 60% de humedad y adentro del domo hay 90%). Grabarles el clima de la sala
# les inventaba un ambiente que no vivieron, así que tienen su propia puerta: `registrar_enraizado`.
RSpec.describe 'POST /salas/:id/registrar_sala', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }

  def registrar
    post "/salas/#{sala.id}/registrar_sala",
         params: { registro_ambiental: { temperatura: 24.5, humedad: 58 } },
         headers: auth_headers
  end

  # Si los únicos lotes de la sala están enraizando, no se les graba el clima del cuarto. Y el aviso
  # tiene que decir POR QUÉ: "no hay lotes activos" haría pensar que la sala está vacía.
  it 'no registra en un lote ENRAIZANDO, y explica dónde va su ambiente' do
    lote = create(:lote, club: club, sala: sala, estado: 'enraizado')
    sign_in_as(admin)

    expect { registrar }.not_to change { lote.registros_ambientales.count }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to match(/enraizando/i)
  end

  it 'alcanza a las fases que respiran el aire de la sala, y saltea a las que enraízan' do
    enr   = create(:lote, club: club, sala: sala, estado: 'enraizado')
    vege  = create(:lote, club: club, sala: sala, estado: 'vegetativo')
    flor  = create(:lote, club: club, sala: sala, estado: 'floracion')
    sign_in_as(admin)

    registrar

    expect(JSON.parse(response.body)['lotes_afectados']).to eq(2)
    [vege, flor].each do |l|
      expect(l.registros_ambientales.count).to eq(1), "#{l.estado} no recibió el registro"
    end
    expect(enr.registros_ambientales.count).to eq(0)
  end

  it 'no registra en lotes que ya no están en la sala' do
    en_sala = create(:lote, club: club, sala: sala, estado: 'vegetativo')
    curado  = create(:lote, club: club, sala: nil, sede: sede, estado: 'curado')
    sign_in_as(admin)

    registrar

    expect(JSON.parse(response.body)['lotes_afectados']).to eq(1)
    expect(en_sala.registros_ambientales.count).to eq(1)
    expect(curado.registros_ambientales.count).to eq(0)
  end

  it 'avisa si la sala no tiene ningún lote de cultivo' do
    create(:lote, club: club, sala: nil, sede: sede, estado: 'finalizado')
    sign_in_as(admin)

    registrar

    expect(response).to have_http_status(:unprocessable_entity)
  end

  # Los estados que reciben registro son, por definición, los que obligan a tener sala.
  it 'la lista usada es la fuente única del modelo, no una copia a mano' do
    expect(Lote::CULTIVO_ESTADOS).to match_array(%w[enraizado vegetativo floracion])
  end
end
