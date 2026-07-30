require 'rails_helper'

# El registro ambiental de una sala se reparte a sus lotes. La lista de estados estaba escrita a
# mano y se olvidaba de `esqueje` y `germinacion` — justo las fases donde el ambiente más importa,
# porque un esqueje sin raíz depende del aire para no deshidratarse.
#
# La regla que fijan estos specs: TODO lo que está físicamente en la sala recibe el registro. Y son
# exactamente los estados para los que el modelo EXIGE sala (`Lote::CULTIVO_ESTADOS`).
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

  # El caso que reportó Germán: una sala donde SOLO hay esquejes. Si el test mezclara estados, el
  # bug pasaba desapercibido porque los de vegetativo sí recibían el registro.
  it 'registra en un lote en ESQUEJE aunque sea el único de la sala' do
    lote = create(:lote, club: club, sala: sala, estado: 'esqueje')
    sign_in_as(admin)

    expect { registrar }.to change { lote.registros_ambientales.count }.by(1)
    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)['lotes_afectados']).to eq(1)
  end

  it 'registra en un lote en GERMINACIÓN aunque sea el único de la sala' do
    lote = create(:lote, club: club, sala: sala, estado: 'germinacion')
    sign_in_as(admin)

    expect { registrar }.to change { lote.registros_ambientales.count }.by(1)
  end

  it 'alcanza a todas las fases que están en la sala, no solo a vegetativo' do
    esq   = create(:lote, club: club, sala: sala, estado: 'esqueje')
    germ  = create(:lote, club: club, sala: sala, estado: 'germinacion')
    vege  = create(:lote, club: club, sala: sala, estado: 'vegetativo')
    flor  = create(:lote, club: club, sala: sala, estado: 'floracion')
    sign_in_as(admin)

    registrar

    expect(JSON.parse(response.body)['lotes_afectados']).to eq(4)
    [esq, germ, vege, flor].each do |l|
      expect(l.registros_ambientales.count).to eq(1), "#{l.estado} no recibió el registro"
    end
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
    expect(Lote::CULTIVO_ESTADOS).to match_array(%w[germinacion esqueje vegetativo floracion])
  end
end
