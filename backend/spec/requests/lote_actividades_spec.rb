require 'rails_helper'

RSpec.describe 'Actividades de lote (LoteEvento tipo=actividad)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  before { sign_in_as(admin) }

  it 'crea una actividad tipada con categoría, fecha pasada y metadata estructurada' do
    fecha = 7.days.ago.to_date
    expect {
      post "/lotes/#{lote.id}/lote_eventos",
           params: { lote_evento: {
             tipo: 'actividad', categoria: 'fertilizacion', descripcion: 'tanda de flora',
             metadata: { producto: 'Bio-Bloom', ec: 1.4 }, registrado_en: "#{fecha}T12:00:00"
           } },
           headers: auth_headers, as: :json
    }.to change(lote.lote_eventos.where(tipo: 'actividad'), :count).by(1)

    expect(response).to have_http_status(:created)
    ev = lote.lote_eventos.actividades.last
    expect(ev.categoria).to eq('fertilizacion')
    expect(ev.registrado_en.to_date).to eq(fecha)
    expect(ev.metadata['producto']).to eq('Bio-Bloom')
    expect(ev.metadata['ec']).to eq(1.4)
  end

  it 'rechaza una actividad sin categoría' do
    post "/lotes/#{lote.id}/lote_eventos",
         params: { lote_evento: { tipo: 'actividad', descripcion: 'x', registrado_en: "#{Date.current}T12:00:00" } },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rechaza una categoría inválida' do
    post "/lotes/#{lote.id}/lote_eventos",
         params: { lote_evento: { tipo: 'actividad', categoria: 'inventada', registrado_en: "#{Date.current}T12:00:00" } },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'la actividad aparece en el timeline del lote con su detalle' do
    post "/lotes/#{lote.id}/lote_eventos",
         params: { lote_evento: {
           tipo: 'actividad', categoria: 'riego', metadata: { ec: 1.2, volumen_l: 5 },
           registrado_en: "#{Date.current}T12:00:00"
         } },
         headers: auth_headers, as: :json

    get "/lotes/#{lote.id}/timeline", headers: auth_headers
    body = JSON.parse(response.body)
    expect(body['actividades']).to be_present
    act = body['actividades'].first
    expect(act['categoria']).to eq('riego')
    expect(act['label']).to eq('Riego')
    expect(act['metadata']['ec']).to eq(1.2)
  end
end
