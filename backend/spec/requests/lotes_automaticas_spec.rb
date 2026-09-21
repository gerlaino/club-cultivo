require 'rails_helper'

# Genética automática (21-sep-2026): florece sola, no depende de la luz. Regla de Germán: un
# solo tilde en la genética; el lote vive en la sala de vegetativo todo el ciclo, se cosecha
# desde vegetativo, y anotar «empezó a florecer» es opcional y no lo mueve de sala. El reloj
# es uno: de la germinación a la cosecha.
RSpec.describe 'Lotes de genética automática', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:vege)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }
  let!(:flora) { create(:sala, club: club, sede: sede, created_by: admin, kind: 'floracion') }
  let(:auto)  { create(:genetica, club: club, nombre: 'Auto Kush', automatica: true, dias_ciclo_objetivo: 75) }
  let(:foto)  { create(:genetica, club: club, nombre: 'Foto Kush', dias_vegetativo_objetivo: 30, tiempo_floracion: 60) }

  def lote_en_vege(gen, plantas: 2)
    l = create(:lote, club: club, sala: vege, genetica: gen, estado: 'vegetativo', start_date: 40.days.ago.to_date,
                      tamanio_maceta: 7, dias_ciclo_objetivo: gen.dias_ciclo_objetivo, dias_vegetativo_objetivo: gen.dias_vegetativo_objetivo)
    plantas.times { create(:plant, lote: l, state: 'vegetativo') }
    l
  end

  before { sign_in_as(admin) }

  it 'el lote hereda los días de semilla a cosecha de la genética y viaja marcado como automático' do
    post '/lotes', params: { sala_id: vege.id, lote: { codigo: 'A-1', genetica_id: auto.id, estado: 'vegetativo',
                                                       start_date: Time.zone.today, plants_count: 1, tamanio_maceta: 7 } }, headers: auth_headers
    expect(response).to have_http_status(:created), response.body
    expect(json).to include('automatica' => true, 'dias_ciclo_objetivo' => 75, 'puede_cosechar' => true)
  end

  it 'el reloj es uno: cosecha cerca del día 75 desde la germinación, aunque siga en vegetativo' do
    lote = lote_en_vege(auto)
    get "/lotes/#{lote.id}", headers: auth_headers
    expect(json['proximo_paso']).to include('fase' => 'cosecha', 'faltan_dias' => 35, 'automatica' => true)
  end

  it 'una fotoperiódica en vegetativo NO puede cosecharse: primero floración' do
    lote = lote_en_vege(foto)
    get "/lotes/#{lote.id}", headers: auth_headers
    expect(json).to include('automatica' => false, 'puede_cosechar' => false)
    expect(json['proximo_paso']).to include('fase' => 'floracion')

    post "/lotes/#{lote.id}/cosechar_plantas", params: { plantas_ids: lote.plants.pluck(:id) }, headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'la automática se cosecha desde vegetativo, y al cosechar todas pasa a cosecha sin pasar por floración' do
    lote = lote_en_vege(auto)
    post "/lotes/#{lote.id}/cosechar_plantas", params: { plantas_ids: lote.plants.pluck(:id), peso_total_g: 300 }, headers: auth_headers
    expect(response).to have_http_status(:created), response.body
    expect(json['estado']).to eq('cosecha')
    expect(json['sala_id']).to be_nil
    expect(lote.lote_eventos.where(tipo: 'cambio_estado').pluck(:estado_anterior, :estado_nuevo)).to eq([%w[vegetativo cosecha]])
  end

  it 'anotar que empezó a florecer es opcional y NO la mueve a la sala de floración' do
    lote = lote_en_vege(auto)
    post "/lotes/#{lote.id}/avanzar_fase", headers: auth_headers
    expect(response).to have_http_status(:ok), response.body
    expect(json['estado']).to eq('floracion')
    expect(json['sala_id']).to eq(vege.id)        # la única sala de floración existe y NO se eligió
    expect(json['puede_cosechar']).to eq(true)
    # Y el reloj sigue siendo el del ciclo entero.
    expect(json['proximo_paso']).to include('fase' => 'cosecha', 'automatica' => true)
  end

  it 'una fotoperiódica que pasa a floración sí se muda a la sala de floración' do
    lote = lote_en_vege(foto)
    post "/lotes/#{lote.id}/avanzar_fase", headers: auth_headers
    expect(response).to have_http_status(:ok), response.body
    expect(json['sala_id']).to eq(flora.id)
  end
end
