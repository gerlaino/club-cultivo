require 'rails_helper'

# AC (Germán, 29-sep): una planta de semilla que todavía no fue a maceta dice «Germinando»; el
# esqueje, «Enraizado». Es la palabra, no la fase: el estado sigue siendo `enraizado`.
RSpec.describe Plant, "#estado_label", type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def planta(origen_lote:, origen_planta: nil, state: 'enraizado')
    lote = create(:lote, club: club, sala: sala, estado: 'enraizado', origen: origen_lote)
    Plant.create!(lote: lote, club: club, nombre: "P-#{SecureRandom.hex(3)}", state: state, origen: origen_planta)
  end

  it 'de un lote de semilla, enraizando: «Germinando»' do
    expect(planta(origen_lote: 'semilla').estado_label).to eq('Germinando')
  end

  it 'de un lote de esquejes, enraizando: «Enraizado»' do
    expect(planta(origen_lote: 'esqueje').estado_label).to eq('Enraizado')
  end

  it 'manda el origen del lote: una planta cargada como semilla en un lote de esquejes dice «Enraizado»' do
    expect(planta(origen_lote: 'esqueje', origen_planta: 'semilla').estado_label).to eq('Enraizado')
  end

  it 'fuera del arranque no dice nada (la pantalla usa la palabra del estado)' do
    expect(planta(origen_lote: 'semilla', state: 'vegetativo').estado_label).to be_nil
  end

  it 'viaja en GET /plants?lote_id' do
    p = planta(origen_lote: 'semilla')
    sign_in_as(admin)
    get '/api/plants', params: { lote_id: p.lote_id }
    expect(JSON.parse(response.body).first['estado_label']).to eq('Germinando')
  end
end
