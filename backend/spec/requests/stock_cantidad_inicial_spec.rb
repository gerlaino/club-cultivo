require 'rails_helper'

RSpec.describe 'Edición de cantidad inicial del stock', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:manicura) { create(:user, :manicura, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }

  describe 'PATCH /stocks/:id (stock externo)' do
    it 'edita la cantidad inicial sin tocar el actual ni crear movimiento' do
      stock = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 800, cantidad_inicial: 1000)
      sign_in_as(admin)

      expect {
        patch "/stocks/#{stock.id}", params: { stock: { cantidad_inicial: 985 } }, headers: auth_headers, as: :json
      }.not_to change { stock.stock_movimientos.count }
      expect(response).to have_http_status(:ok)
      stock.reload
      expect(stock.cantidad_inicial.to_f).to eq(985.0) # inicial corregido
      expect(stock.cantidad.to_f).to eq(800.0)         # actual intacto
    end

    it 'no permite editar la inicial de un stock de lote (viene del pesaje)' do
      sala  = create(:sala, club: club, sede: sede, created_by: admin)
      lote  = create(:lote, club: club, sala: sala)
      stock = create(:stock, club: club, sede: sede, lote: lote, origen: 'lote', cantidad: 100, cantidad_inicial: 100)
      sign_in_as(admin)

      patch "/stocks/#{stock.id}", params: { stock: { cantidad_inicial: 120 } }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(stock.reload.cantidad_inicial.to_f).to eq(100.0)
    end
  end

  describe 'PATCH /lotes/:lote_id/pesajes_manicura/:id/reajustar_peso (stock de lote)' do
    let(:sala)    { create(:sala, club: club, sede: sede, created_by: admin, kind: 'manicura') }
    let(:lote)    { create(:lote, club: club, sala: sala, estado: 'en_manicura', manicurador: manicura) }
    let!(:planta) { create(:plant, lote: lote, club: club, state: 'cosechado') }

    it 'reajustar el peso del pesaje propaga la diferencia al stock' do
      pesaje = lote.pesajes_manicura.create!(
        manicurador: manicura, club: club, fecha_pesaje: Date.current,
        estado: 'enviado', enviado_at: Time.current, peso_total_g: 200, plantas_count: 1,
      )
      sign_in_as(admin)
      post "/lotes/#{lote.id}/pesajes_manicura/#{pesaje.id}/confirmar",
           params: { peso_confirmado_g: 200 }, headers: auth_headers, as: :json
      stock = Stock.last
      expect(stock.cantidad.to_f).to eq(200.0)

      patch "/lotes/#{lote.id}/pesajes_manicura/#{pesaje.id}/reajustar_peso",
            params: { peso_confirmado_g: 250 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      stock.reload
      expect(stock.cantidad.to_f).to eq(250.0)          # 200 + 50
      expect(stock.cantidad_inicial.to_f).to eq(250.0)  # inicial también sube
      expect(pesaje.reload.peso_confirmado_g.to_f).to eq(250.0)
    end
  end
end
