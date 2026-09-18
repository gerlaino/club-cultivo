require 'rails_helper'

# Consumo propio (uso personal, sep-2026). El cultivador de casa no dispensa: saca del frasco
# para él. Es la única salida parcial que no pasa por una dispensación y existe SÓLO en el plan
# personal — en una organización lo trazable sale por dispensación y nada más.
RSpec.describe 'POST /stocks/:id/consumir', type: :request do
  include AuthHelpers

  let(:sede)  { create(:sede, club: club) }
  let(:lote)  { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) }
  let(:stock) { create(:stock, club: club, sede: sede, lote: lote, cantidad: 30) }

  def json = JSON.parse(response.body)

  context 'en uso personal' do
    let(:club)  { create(:club, plan: 'personal', features: { 'cultivo' => true }) }
    let(:admin) { create(:user, :admin, club: club) }
    before { sign_in_as(admin) }

    it 'baja el frasco y deja el movimiento con su fecha' do
      post "/stocks/#{stock.id}/consumir", params: { cantidad: 2.5, fecha: (Time.zone.today - 1).to_s, nota: 'noche' }, as: :json

      expect(response).to have_http_status(:ok), response.body
      expect(stock.reload.cantidad.to_f).to eq(27.5)
      mov = stock.stock_movimientos.where(tipo: 'consumo').last
      expect(mov.gramos.to_f).to eq(-2.5)
      expect(mov.fecha).to eq(Time.zone.today - 1)
      expect(mov.notas).to eq('noche')
    end

    it 'no deja consumir más de lo que queda' do
      post "/stocks/#{stock.id}/consumir", params: { cantidad: 31 }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to include('quedan')
      expect(stock.reload.cantidad.to_f).to eq(30)
    end

    it 'ni una cantidad vacía o negativa' do
      post "/stocks/#{stock.id}/consumir", params: { cantidad: 0 }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'consumir lo último agota el frasco' do
      post "/stocks/#{stock.id}/consumir", params: { cantidad: 30 }, as: :json

      expect(response).to have_http_status(:ok), response.body
      expect(stock.reload).to be_agotado
    end

    it 'la trazabilidad lo cuenta como consumido, no como merma ni sin explicar' do
      post "/stocks/#{stock.id}/consumir", params: { cantidad: 10 }, as: :json

      t = Stocks::Trazabilidad.new(stock: stock.reload).call
      expect(t[:totales][:sin_explicar_g].to_f).to eq(0)
      expect(t[:salidas].map { |s| s[:tipo] }).to include('consumo')
      expect(t[:frase]).to include('se consumieron')
    end
  end

  context 'en una organización' do
    let(:club)  { create(:club, plan: 'basico') }
    let(:admin) { create(:user, :admin, club: club) }
    before { sign_in_as(admin) }

    it 'no existe: lo trazable sale por dispensación' do
      post "/stocks/#{stock.id}/consumir", params: { cantidad: 1 }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(stock.reload.cantidad.to_f).to eq(30)
    end
  end
end
