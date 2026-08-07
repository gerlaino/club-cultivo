require 'rails_helper'

# AC: el admin/supervisor tiene la última palabra. Si él registra el peso, queda CONFIRMADO
# y genera el stock en el acto — no entra a la cola de aprobación, porque el único que
# podría aprobarlo es él mismo.
RSpec.describe 'Manicura registrada por admin', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)  { create(:sala, sede: sede, club: club) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'en_manicura') }

  before { sign_in_as(admin) }

  def plantas!(n)
    n.times.map { create(:plant, lote: lote, club: club, state: 'cosechado') }
  end

  it 'el peso queda confirmado y genera stock, sin pasar por aprobación' do
    ps = plantas!(3)

    post "/api/lotes/#{lote.id}/pesajes_manicura/registrar_directo",
         params: { resto: { plant_ids: ps.map(&:id), peso_total_g: 300 } }, as: :json

    expect(response).to have_http_status(:created)
    pesaje = lote.pesajes_manicura.last
    expect(pesaje.estado).to eq('confirmado')
    expect(JSON.parse(response.body)['stock_id']).to be_present
  end

  it 'reparte el peso SOLO entre las plantas elegidas' do
    ps = plantas!(4)
    elegidas = ps.first(2)

    post "/api/lotes/#{lote.id}/pesajes_manicura/registrar_directo",
         params: { resto: { plant_ids: elegidas.map(&:id), peso_total_g: 200 } }, as: :json

    expect(response).to have_http_status(:created)
    expect(elegidas.map { |p| p.reload.peso_seco.to_f }).to all(eq(100.0))
    expect(ps.last(2).map { |p| p.reload.peso_seco }).to all(be_blank)
  end

  # El candado de manicura asignada sigue mandando: si el lote es de otra persona, ni el
  # admin lo pesa por ella.
  it 'no aplica si el lote está asignado a otro responsable' do
    plantas!(2)
    lote.update!(manicurador: create(:user, :manicura, club: club))

    post "/api/lotes/#{lote.id}/pesajes_manicura/registrar_directo",
         params: { resto: { peso_total_g: 100 } }, as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it 'el pesaje de un manicura SÍ queda pendiente de aprobación' do
    manicura = create(:user, :manicura, club: club)
    ps = plantas!(2)
    sign_in_as(manicura)

    post "/api/lotes/#{lote.id}/pesajes_manicura",
         params: { plant_ids: ps.map(&:id), peso_total_g: 200, enviar: true }, as: :json

    expect(response).to have_http_status(:created)
    expect(lote.pesajes_manicura.last.estado).to eq('enviado')
  end
end
