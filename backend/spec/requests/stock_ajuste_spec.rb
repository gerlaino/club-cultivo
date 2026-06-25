require 'rails_helper'

RSpec.describe 'POST /stocks/:id/ajuste (por cantidad real)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club) }
  let(:lote)  { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) }
  let(:stock) { create(:stock, club: club, sede: sede, lote: lote, cantidad: 100) }

  before { sign_in_as(admin) }

  it 'calcula el delta desde la cantidad real ingresada' do
    post "/stocks/#{stock.id}/ajuste",
         params: { tipo: 'reconteo', cantidad_real: 92.5, motivo: 'reconteo físico' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(stock.reload.cantidad.to_f).to eq(92.5)
    mov = stock.stock_movimientos.where(tipo: 'ajuste').last
    expect(mov.gramos.to_f).to eq(-7.5)   # 92.5 - 100
  end

  it 'rechaza si la cantidad real es igual a la actual (delta 0)' do
    post "/stocks/#{stock.id}/ajuste",
         params: { tipo: 'reconteo', cantidad_real: 100, motivo: 'x' },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
