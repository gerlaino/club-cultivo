require 'rails_helper'

RSpec.describe 'POST /lotes/:lote_id/lote_eventos (evento pasado)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala) }

  it 'registra una nota con fecha pasada (backdate) sin tocar el estado del lote' do
    sign_in_as(admin)
    estado_previo = lote.estado
    fecha = 10.days.ago.to_date

    expect {
      post "/lotes/#{lote.id}/lote_eventos",
           params: { lote_evento: { tipo: 'nota', descripcion: '💧 Riego: con 1.2 EC', registrado_en: "#{fecha}T12:00:00" } },
           headers: auth_headers
    }.to change(lote.lote_eventos.where(tipo: 'nota'), :count).by(1)

    expect(response).to have_http_status(:created)
    ev = lote.lote_eventos.where(tipo: 'nota').last
    expect(ev.registrado_en.to_date).to eq(fecha)
    expect(lote.reload.estado).to eq(estado_previo)
  end
end
