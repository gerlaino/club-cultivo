require 'rails_helper'

RSpec.describe 'GET /lotes/:id/historial (bitácora unificada)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }
  let!(:p1)   { create(:plant, lote: lote) }

  before { sign_in_as(admin) }

  it 'normaliza actividades, fases y trasplantes en una sola lista ordenada' do
    # una actividad manual
    lote.lote_eventos.create!(tipo: 'actividad', categoria: 'riego', user: admin, club: club,
                              registrado_en: 3.days.ago, metadata: { 'ec' => 1.2 })
    # un cambio de fase
    lote.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'vegetativo', estado_nuevo: 'floracion',
                              user: admin, club: club, registrado_en: 5.days.ago)
    # un trasplante (vía service → deja su rastro en el historial)
    Lotes::RegistrarTrasplante.call(lote: lote, usuario: admin, destino: 7, origen: 3, fecha: 1.day.ago.to_date.to_s)

    get "/lotes/#{lote.id}/historial", headers: auth_headers
    expect(response).to have_http_status(:ok)
    items = JSON.parse(response.body)['historial']

    kinds = items.map { |i| i['kind'] }
    expect(kinds).to include('actividad', 'fase')
    expect(items.any? { |i| i['categoria'] == 'trasplante' }).to be(true)

    # ordenado por fecha desc
    fechas = items.map { |i| i['fecha'] }.compact
    expect(fechas).to eq(fechas.sort.reverse)

    # la actividad de riego es editable; la fase no
    riego = items.find { |i| i['categoria'] == 'riego' }
    fase  = items.find { |i| i['kind'] == 'fase' }
    expect(riego['editable']).to be(true)
    expect(riego['metadata']['ec']).to eq(1.2)
    expect(fase['editable']).to be(false)
  end
end
