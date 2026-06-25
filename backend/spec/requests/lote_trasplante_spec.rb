require 'rails_helper'

RSpec.describe 'POST /lotes/:id/registrar_trasplante', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, tamanio_maceta: 1) }
  let!(:p1)   { create(:plant, lote: lote) }
  let!(:p2)   { create(:plant, lote: lote) }

  it 'registra el trasplante (PlantActivity por planta) y actualiza la maceta del lote' do
    sign_in_as(admin)
    expect {
      post "/lotes/#{lote.id}/registrar_trasplante",
           params: { fecha: Date.current.to_s, maceta_origen_l: 1, maceta_destino_l: 3 },
           headers: auth_headers
    }.to change(PlantActivity.where(activity_type: 'transplant'), :count).by(2)

    expect(response).to have_http_status(:ok)
    expect(lote.reload.tamanio_maceta.to_f).to eq(3.0)
    act = p1.activities.where(activity_type: 'transplant').last
    expect(act.metadata['maceta_origen_l']).to eq(1.0)
    expect(act.metadata['maceta_destino_l']).to eq(3.0)
  end

  it 'aparece en la timeline del lote agrupado por maceta' do
    sign_in_as(admin)
    post "/lotes/#{lote.id}/registrar_trasplante",
         params: { fecha: Date.current.to_s, maceta_origen_l: 1, maceta_destino_l: 3 },
         headers: auth_headers
    get "/lotes/#{lote.id}/timeline", headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['transplantes']).to be_present
    expect(body['transplantes'].first['maceta_destino']).to eq(3.0)
  end

  it 'rechaza sin maceta destino' do
    sign_in_as(admin)
    post "/lotes/#{lote.id}/registrar_trasplante", params: { fecha: Date.current.to_s }, headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
