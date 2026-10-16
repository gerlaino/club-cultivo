require 'rails_helper'

# AC (Germán, 15-oct-2026): «agregar en historial stock filtro para poder ver los cerrados… esos
# stocks no los encuentro… quiero poder ver los eliminados en historial y los agotados y poder
# diferenciar, porque ahora esa diferencia de 145 no sabemos por qué». Un stock eliminado
# desaparecía de todos lados; el historial ahora lo trae y cada uno dice qué le pasó.
RSpec.describe 'Stock · historial: eliminados, cerrados y agotados', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club, first_name: 'Ana', last_name: 'Paz') }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  def nuevo(cantidad: 50) = Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'Coop', forma_producto: 'flor_seca',
                                          unidad: 'g', cantidad: cantidad, descripcion: 'Fruti Punchi')

  let!(:vivo)      { nuevo }
  let!(:agotado)   { nuevo.tap { |s| s.update!(cantidad: 0, estado: 'agotado') } }
  let!(:cerrado)   { nuevo }
  let!(:eliminado) { nuevo(cantidad: 145.7) }

  before { sign_in_as(admin) }

  def historial
    get '/api/stocks', params: { historial: true }
    expect(response).to have_http_status(:ok)
    response.parsed_body.index_by { |h| h['id'] }
  end

  before do
    post "/api/stocks/#{cerrado.id}/descartar", params: { motivo: 'destruido', detalle: 'hongos' }, as: :json
    expect(response).to have_http_status(:ok), response.body
    delete "/api/stocks/#{eliminado.id}"
    expect(response).to have_http_status(:no_content)
  end

  it 'el eliminado aparece en el historial, con cuándo y quién' do
    h = historial[eliminado.id]
    expect(h).to include('situacion' => 'eliminado', 'eliminado_por' => 'Ana Paz', 'numero_lote_producto' => eliminado.numero_lote_producto)
    expect(h['eliminado_at']).to be_present
  end

  it 'cada uno dice su situación: asignado, agotado, cerrado (con motivo) y eliminado' do
    h = historial
    expect(h[vivo.id]['situacion']).to eq('asignado')
    expect(h[agotado.id]['situacion']).to eq('agotado')
    expect(h[cerrado.id]).to include('situacion' => 'cerrado', 'cierre_motivo' => 'Destruido / descartado', 'cierre_gramos' => 50.0)
    expect(h[eliminado.id]['situacion']).to eq('eliminado')
  end

  it 'la ficha de un eliminado se puede mirar, con sus movimientos' do
    get "/api/stocks/#{eliminado.id}"
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data']).to include('situacion' => 'eliminado', 'eliminado_por' => 'Ana Paz')

    get "/api/stocks/#{eliminado.id}/movimientos"
    expect(response).to have_http_status(:ok)
  end

  # Germán, 15-oct-2026: «un stock finalizado o agotado no me debería dejar ajustar, repartir…».
  # La ficha apaga esas acciones con `agotado`, que no llegaba: todos los botones quedaban prendidos.
  it 'la ficha dice si está agotado, para apagar las acciones' do
    get "/api/stocks/#{agotado.id}"
    expect(response.parsed_body['data']).to include('agotado' => true, 'situacion' => 'agotado')
    get "/api/stocks/#{cerrado.id}"
    expect(response.parsed_body['data']).to include('agotado' => true, 'situacion' => 'cerrado')
    get "/api/stocks/#{vivo.id}"
    expect(response.parsed_body['data']).to include('agotado' => false)
  end

  it 'un eliminado no se puede tocar' do
    post "/api/stocks/#{eliminado.id}/ajuste", params: { gramos: 10, motivo: 'correccion' }, as: :json
    expect(response).to have_http_status(:not_found)
  end

  describe 'aislamiento de tenant' do
    let(:otro_club) { create(:club) }
    let(:otro)      { create(:user, :admin, club: otro_club) }

    it 'otra organización no ve los eliminados de esta ni su ficha' do
      sign_in_as(otro)
      get '/api/stocks', params: { historial: true }
      expect(response.parsed_body.map { |h| h['id'] }).not_to include(eliminado.id, vivo.id)

      get "/api/stocks/#{eliminado.id}"
      expect(response).to have_http_status(:not_found)
    end
  end
end
