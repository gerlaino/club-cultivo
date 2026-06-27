require 'rails_helper'

# Fase 3 del refactor multi-stock: una sola dispensación puede abarcar varios stocks (líneas).
RSpec.describe 'Dispensación multi-stock', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin) }
  let!(:stock_a) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }
  let!(:stock_b) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'hash',      unidad: 'g', cantidad: 50,  precio_sugerido_ars: 200) }

  before { sign_in_as(dispensador) }

  def crear(items, extra = {})
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { medio_pago: 'efectivo', items: items }.merge(extra) },
         headers: auth_headers
  end

  it 'crea UNA dispensa con varias líneas, descuenta cada stock y suma el total' do
    crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }])

    expect(response).to have_http_status(:created)
    d = Dispensacion.last
    expect(d.items.count).to eq(2)
    expect(d.multi_stock?).to be true
    expect(d.cantidad_total).to eq(15)                       # 10 + 5
    expect(d.aporte_socio_ars).to eq(2000)                   # 10*100 + 5*200
    expect(stock_a.reload.cantidad).to eq(90)                # descontó su línea
    expect(stock_b.reload.cantidad).to eq(45)
  end

  it 'cada línea guarda su propio snapshot de trazabilidad' do
    crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }])
    d = Dispensacion.last
    expect(d.items.map(&:lote_codigo).uniq).to eq([lote.codigo])
  end

  it 'bloquea si una línea excede el stock disponible y no descuenta nada' do
    crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 999 }])

    expect(response).to have_http_status(:unprocessable_entity)
    expect(stock_a.reload.cantidad).to eq(100)               # rollback total
    expect(stock_b.reload.cantidad).to eq(50)
  end

  it 'al borrar la dispensa multi-stock, revierte el stock de todas las líneas' do
    crear([{ stock_id: stock_a.id, cantidad: 10 }, { stock_id: stock_b.id, cantidad: 5 }])
    d = Dispensacion.last
    d.destroy
    expect(stock_a.reload.cantidad).to eq(100)
    expect(stock_b.reload.cantidad).to eq(50)
  end
end
