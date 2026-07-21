require 'rails_helper'

RSpec.describe 'GET /plants/:id/plant_activities (historial de la planta)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }
  let(:plant) { create(:plant, lote: lote) }

  before { sign_in_as(admin) }

  it 'hereda el contexto del lote (ambiente + fases + actividades) además de lo propio' do
    lote.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'vegetativo', estado_nuevo: 'floracion',
                              user: admin, club: club, registrado_en: 5.days.ago)
    lote.lote_eventos.create!(tipo: 'actividad', categoria: 'riego', user: admin, club: club,
                              registrado_en: 3.days.ago, metadata: { 'ec' => 1.2 })
    create(:registro_ambiental, lote: lote, user: admin, registrado_en: 4.days.ago)
    plant.activities.create!(activity_type: 'transplant', user: admin, occurred_at: 2.days.ago,
                             metadata: { 'maceta_destino_l' => 7 })

    get "/plants/#{plant.id}/plant_activities", headers: auth_headers
    expect(response).to have_http_status(:ok)
    tipos = JSON.parse(response.body).map { |a| a['activity_type'] }
    expect(tipos).to include('transplant', 'lote_fase', 'lote_actividad', 'registro_ambiental_lote')
  end

  it 'NO hereda las notas del lote (ej. el descarte de OTRA planta)' do
    otra = create(:plant, lote: lote)
    patch "/plants/#{otra.id}", params: { plant: { state: 'descartada' }, motivo: 'se secó' }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)

    get "/plants/#{plant.id}/plant_activities", headers: auth_headers
    body = JSON.parse(response.body)
    expect(body.map { |a| a['activity_type'] }).not_to include('lote_nota')
    expect(body.map { |a| a['description'].to_s }).to all(satisfy { |d| !d.include?('descartada') })
  end

  it 'no duplica el trasplante: muestra el de la planta, no el evento del lote' do
    plant # fuerza la creación antes del trasplante
    Lotes::RegistrarTrasplante.call(lote: lote, usuario: admin, destino: 7, origen: 3, fecha: 2.days.ago.to_date.to_s)

    get "/plants/#{plant.id}/plant_activities", headers: auth_headers
    body = JSON.parse(response.body)
    expect(body.count { |a| a['activity_type'] == 'transplant' }).to eq(1)
    expect(body.any? { |a| a['activity_type'] == 'lote_actividad' && a['description'].to_s.include?('Trasplante') }).to be(false)
  end

  it 'el descarte de la planta queda en su propio historial, con el motivo' do
    patch "/plants/#{plant.id}", params: { plant: { state: 'descartada' }, motivo: 'plaga' }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)

    get "/plants/#{plant.id}/plant_activities", headers: auth_headers
    descarte = JSON.parse(response.body).find { |a| a['description'].to_s.include?('Descartada') }
    expect(descarte).to be_present
    expect(descarte['description']).to include('plaga')
  end
end
