require 'rails_helper'

# El KPI "ambiente" de la ficha de sala tiene que ser el aire DE ESA SALA.
#
# `RegistroAmbiental` cuelga del LOTE y no guarda dónde se midió, así que al mover un lote de cuarto
# sus registros viejos se le atribuían a la sala nueva: una sala donde nunca se registró nada
# mostraba el ambiente de otra. `LecturaAmbiental` sí guarda `sala_id` al momento de medir, y es la
# que manda.
RSpec.describe 'GET /salas/:id — ambiente_actual', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:vieja) { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }
  let(:nueva) { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }

  before { sign_in_as(admin) }

  def ambiente_de(sala)
    get "/api/salas/#{sala.id}"
    JSON.parse(response.body)['ambiente_actual']
  end

  it 'el registro queda en la sala donde se midió, aunque el lote se mude' do
    lote = create(:lote, club: club, sala: vieja, estado: 'vegetativo', tamanio_maceta: 3)
    post "/api/salas/#{vieja.id}/registrar_sala",
         params: { registro_ambiental: { temperatura: 24, humedad: 70 } }
    expect(response).to have_http_status(:created)

    # El lote se muda: se lleva sus plantas, no el aire que respiró en el otro cuarto.
    post '/api/lotes/mover', params: { lote_ids: [lote.id], sala_id: nueva.id }
    expect(response).to have_http_status(:success)

    expect(ambiente_de(vieja)&.dig('temperatura')).to eq(24.0)
    expect(ambiente_de(nueva)).to be_nil
  end

  # Lo medido EN esta sala sigue siendo suyo aunque el lote ya haya terminado: es dato real del
  # cuarto y viaja con su antigüedad, que es la que avisa que no es de ahora.
  it 'conserva lo medido en la sala aunque el lote haya terminado su ciclo' do
    viejo = create(:lote, club: club, sala: vieja, estado: 'vegetativo', tamanio_maceta: 3)
    viejo.registros_ambientales.create!(
      club: club, user: admin, registrado_en: 3.days.ago, temperatura: 23, humedad: 65, fuente: 'manual',
    )
    viejo.update!(estado: 'finalizado')

    amb = ambiente_de(vieja)
    expect(amb['temperatura']).to eq(23.0)
    expect(Date.parse(amb['registrado_en'])).to eq(3.days.ago.to_date)
    # …pero no se le atribuye a ninguna otra sala.
    expect(ambiente_de(nueva)).to be_nil
  end

  # Una sala sin ninguna medición propia no muestra el aire de nadie.
  it 'no inventa un ambiente cuando nunca se midió en esa sala' do
    create(:lote, club: club, sala: nueva, estado: 'vegetativo', tamanio_maceta: 3)
    expect(ambiente_de(nueva)).to be_nil
  end

  it 'no mezcla la temperatura de un momento con la humedad de otro' do
    lote = create(:lote, club: club, sala: vieja, estado: 'vegetativo', tamanio_maceta: 3)
    lote.registros_ambientales.create!(
      club: club, user: admin, registrado_en: 2.days.ago, temperatura: 30, humedad: 30, fuente: 'manual',
    )
    lote.registros_ambientales.create!(
      club: club, user: admin, registrado_en: 1.hour.ago, temperatura: 22, humedad: 60, fuente: 'manual',
    )

    amb = ambiente_de(vieja)
    expect(amb['temperatura']).to eq(22.0)
    expect(amb['humedad']).to eq(60.0)   # la del mismo momento, no la de hace dos días
  end
end
