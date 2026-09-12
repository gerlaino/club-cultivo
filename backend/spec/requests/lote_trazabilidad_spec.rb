require 'rails_helper'

# LA TRAZABILIDAD ARRANCA TAMBIÉN DESDE EL LOTE (Germán, sep-2026): un lote en floración no tiene
# frasco todavía y la pregunta del auditor puede empezar por la planta. Es la misma cadena,
# cortada antes, más los frascos que salieron de él.
RSpec.describe 'GET /lotes/:id/trazabilidad', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, estado: 'floracion') }

  before { sign_in_as(admin) }

  it 'un lote en cultivo tiene cadena aunque no tenga frasco' do
    create(:plant, lote: lote, club: club, nombre: 'L-1-P001', state: 'floracion')
    create(:plant, lote: lote, club: club, nombre: 'L-1-P002', state: 'descartada', motivo_descarte: 'macho')
    lote.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'floracion', club: club, user: admin, registrado_en: 10.days.ago)

    get "/api/lotes/#{lote.id}/trazabilidad"
    expect(response).to have_http_status(:ok), response.body
    b = JSON.parse(response.body)
    expect(b['lote']['codigo']).to eq(lote.codigo)
    expect(b['plantas'].map { |p| p['nombre'] }).to eq(['L-1-P001'])
    expect(b['plantas_descartadas'].first['motivo_descarte']).to eq('macho')
    expect(b['cronologia'].map { |c| c['tipo'] }).to eq(['estado'])
    expect(b['frascos']).to eq([])
  end

  it 'lista los frascos que salieron de él' do
    st = Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 1)
    get "/api/lotes/#{lote.id}/trazabilidad"
    expect(JSON.parse(response.body)['frascos'].first['numero']).to eq(st.numero_lote_producto)
  end

  it 'no muestra un lote de otra organización' do
    otro = create(:club)
    ajeno = ActsAsTenant.with_tenant(otro) { create(:lote, club: otro, sala: create(:sala, club: otro, sede: create(:sede, club: otro, tipo: 'mixta'))) }
    get "/api/lotes/#{ajeno.id}/trazabilidad"
    expect(response).to have_http_status(:not_found)
  end
end
