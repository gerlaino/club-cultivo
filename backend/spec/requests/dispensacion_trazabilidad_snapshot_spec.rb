require 'rails_helper'

RSpec.describe 'Dispensación — snapshot de trazabilidad', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:genetica) { create(:genetica, club: club, nombre: 'Northern Lights') }
  let(:lote)     { create(:lote, club: club, sala: sala, genetica: genetica, codigo: 'LOTE-007') }
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, genetica: genetica, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  before { sign_in_as(admin) }

  it 'guarda código de lote y genética al crear la dispensación' do
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today.to_s } },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:created)
    d = Dispensacion.last
    expect(d.lote_codigo).to eq('LOTE-007')
    expect(d.genetica_nombre).to eq('Northern Lights')
  end

  it 'el snapshot sobrevive aunque se elimine el stock de origen' do
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today.to_s } },
         headers: auth_headers, as: :json
    d = Dispensacion.last

    stock.destroy   # dependent: :nullify deja la dispensación pero sin stock
    d.reload
    expect(d.stock_id).to be_nil               # se perdió el FK
    expect(d.lote_codigo).to eq('LOTE-007')    # pero la trazabilidad persiste
    expect(d.genetica_nombre).to eq('Northern Lights')
  end
end
