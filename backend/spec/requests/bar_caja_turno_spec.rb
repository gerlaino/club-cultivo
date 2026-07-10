require 'rails_helper'

RSpec.describe 'Bar caja de turno', type: :request do
  let(:club)  { create(:club, features: { 'bar' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:bar)   { create(:barra, club: club, sede: sede) }
  let!(:producto) { create(:bar_producto, club: club, bar: bar, precio_ars: 1000, costo_ars: 400, stock: 50) }

  before { sign_in_as(admin) }

  def abrir(monto: 5000)
    post "/bares/#{bar.id}/cajas/abrir", params: { monto_inicial_ars: monto }, headers: auth_headers, as: :json
  end

  def vender(cant: 2, medio: 'efectivo')
    Bar::RegistrarVenta.new(bar, admin, lineas: [{ bar_producto_id: producto.id, cantidad: cant }], medio_pago: medio).call
  end

  describe 'apertura' do
    it 'abre una caja con el fondo inicial' do
      abrir(monto: 5000)
      expect(response).to have_http_status(:created)
      expect(bar.caja_abierta).to be_present
      expect(bar.caja_abierta.monto_inicial_ars.to_f).to eq(5000.0)
    end

    it 'no permite dos cajas abiertas a la vez' do
      abrir
      abrir
      expect(response).to have_http_status(:unprocessable_entity)
      expect(bar.caja_turnos.abiertas.count).to eq(1)
    end
  end

  describe 'ventas del turno' do
    it 'engancha las ventas a la caja abierta' do
      abrir
      caja = bar.caja_abierta
      venta = vender(cant: 2)
      expect(venta.caja_turno_id).to eq(caja.id)
      expect(caja.reload.total_ventas_ars).to eq(2000.0)
      expect(caja.tickets).to eq(1)
    end

    it 'no engancha ventas si no hay caja abierta' do
      venta = vender(cant: 1)
      expect(venta.caja_turno_id).to be_nil
    end
  end

  describe 'cierre con arqueo' do
    it 'cierra la caja y calcula el efectivo esperado (fondo + ventas en efectivo)' do
      abrir(monto: 5000)
      vender(cant: 2, medio: 'efectivo')       # +2000 efectivo
      vender(cant: 1, medio: 'transferencia')  # +1000 digital (no suma al esperado)
      caja = bar.caja_abierta

      post "/bares/#{bar.id}/cajas/#{caja.id}/cerrar",
           params: { efectivo_declarado_ars: 7000 }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      caja.reload
      expect(caja.estado).to eq('cerrada')
      expect(caja.efectivo_esperado_ars).to eq(7000.0) # 5000 + 2000
      expect(caja.diferencia_ars).to eq(0.0)           # contó 7000 = esperado
    end

    it 'reporta la diferencia de arqueo cuando falta plata' do
      abrir(monto: 5000)
      vender(cant: 2, medio: 'efectivo')  # esperado 7000
      caja = bar.caja_abierta

      post "/bares/#{bar.id}/cajas/#{caja.id}/cerrar",
           params: { efectivo_declarado_ars: 6500 }, headers: auth_headers, as: :json

      expect(caja.reload.diferencia_ars).to eq(-500.0) # faltan 500
    end

    it 'no permite cerrar dos veces' do
      abrir
      caja = bar.caja_abierta
      post "/bares/#{bar.id}/cajas/#{caja.id}/cerrar", params: { efectivo_declarado_ars: 5000 }, headers: auth_headers, as: :json
      post "/bares/#{bar.id}/cajas/#{caja.id}/cerrar", params: { efectivo_declarado_ars: 5000 }, headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
