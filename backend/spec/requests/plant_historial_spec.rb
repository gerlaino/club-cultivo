require 'rails_helper'

RSpec.describe 'GET /plants/:id/plant_activities (historial heredado del lote)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }
  let(:plant) { create(:plant, lote: lote) }

  before { sign_in_as(admin) }

  it 'incluye los cambios de fase y las actividades del lote, además de las de la planta' do
    lote.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'vegetativo', estado_nuevo: 'floracion',
                              user: admin, club: club, registrado_en: 5.days.ago)
    lote.lote_eventos.create!(tipo: 'actividad', categoria: 'riego', user: admin, club: club,
                              registrado_en: 3.days.ago, metadata: { 'ec' => 1.2 })
    plant.activities.create!(activity_type: 'transplant', user: admin, occurred_at: 2.days.ago,
                             metadata: { 'maceta_destino_l' => 7 })

    get "/plants/#{plant.id}/plant_activities", headers: auth_headers
    expect(response).to have_http_status(:ok)
    tipos = JSON.parse(response.body).map { |a| a['activity_type'] }
    expect(tipos).to include('lote_fase', 'lote_actividad', 'transplant')
  end

  it 'no duplica el trasplante: muestra el de la planta, no el evento de lote' do
    plant   # fuerza la creación de la planta antes del trasplante
    # registrar_trasplante crea el PlantActivity de la planta + un LoteEvento resumen
    Lotes::RegistrarTrasplante.call(lote: lote, usuario: admin, destino: 7, origen: 3, fecha: 2.days.ago.to_date.to_s)

    get "/plants/#{plant.id}/plant_activities", headers: auth_headers
    body = JSON.parse(response.body)
    transplantes = body.select { |a| a['activity_type'] == 'transplant' || a['activity_type'] == 'lote_actividad' && a['description'].to_s.include?('Trasplante') }
    # solo el PlantActivity de la planta, no el heredado del lote
    expect(body.count { |a| a['activity_type'] == 'transplant' }).to eq(1)
    expect(body.any? { |a| a['activity_type'] == 'lote_actividad' && a['description'].to_s.include?('Trasplante') }).to be(false)
  end
end
