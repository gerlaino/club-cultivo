require 'rails_helper'

# AC (Germán, 20-oct-2026): una planta cosechada o descartada ya no crece, así que no recibe
# registros de cultivo (poda, medición, trasplante, registro). La ficha no los ofrece y el backend
# los rechaza por cualquier puerta. Una nota sí.
RSpec.describe 'Registros sobre una planta fuera de cultivo', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, created_by: admin)) } }
  let(:planta) { ActsAsTenant.with_tenant(club) { create(:plant, lote: lote, club: club) } }

  def registrar(tipo)
    post "/plants/#{planta.id}/plant_activities", params: { plant_activity: { activity_type: tipo, description: 'x' } }, headers: auth_headers
  end

  before { sign_in_as(admin) }

  it 'en cultivo: la ficha lo dice y la poda se registra' do
    get "/plants/#{planta.id}", headers: auth_headers
    expect(json['en_cultivo']).to be(true)

    registrar('pruning')
    expect(response).to have_http_status(:created)
  end

  %w[descartada cosechado].each do |estado|
    it "#{estado}: la ficha lo dice, la poda y el registro se rechazan con el motivo, la nota pasa" do
      planta.update_columns(state: estado)
      get "/plants/#{planta.id}", headers: auth_headers
      expect(json['en_cultivo']).to be(false)

      registrar('pruning')
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].join).to match(/ya no recibe registros de cultivo/)

      registrar('registro_planta')
      expect(response).to have_http_status(:unprocessable_entity)

      registrar('note')
      expect(response).to have_http_status(:created)
    end
  end
end
