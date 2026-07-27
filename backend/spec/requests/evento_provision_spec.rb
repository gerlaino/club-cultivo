require 'rails_helper'

RSpec.describe 'Provisión + reserva de eventos', type: :request do
  let(:club)   { create(:club, features: { 'bar' => true }) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:sede)   { create(:sede, club: club, tipo: 'social') }
  let(:bar)    { create(:barra, club: club, sede: sede) }
  let(:evento) { bar.eventos_bar.create!(club: club, nombre: 'Fiesta', estado: 'planificado') }
  let!(:cerveza) { create(:bar_producto, club: club, bar: bar, nombre: 'Cerveza', stock: 30, costo_ars: 500) }

  before { sign_in_as(admin) }

  def path(extra = '') = "/bares/#{bar.id}/eventos/#{evento.id}/provisiones#{extra}"

  def proveer(cantidad)
    post path, params: { bar_producto_id: cerveza.id, cantidad_prevista: cantidad }, headers: auth_headers, as: :json
  end

  it 'arma la provisión y calcula el faltante contra el depósito' do
    proveer(48) # hay 30 en depósito → faltan 18
    expect(response).to have_http_status(:created)
    fila = JSON.parse(response.body)
    expect(fila['faltante']).to eq(18.0)
  end

  # Reserva PARCIAL: si falta stock, aparta lo que hay y avisa el faltante (antes abortaba todo).
  it 'reserva lo disponible y avisa el faltante' do
    proveer(48) # hay 30 en depósito → faltan 18
    post path('/reservar'), headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(cerveza.reload.stock).to eq(0) # se apartaron los 30 que había

    body = JSON.parse(response.body)
    expect(body['advertencias'].first).to include('Cerveza', '30', '48')
    prov = evento.provisiones.first
    expect(prov.cantidad_reservada).to eq(30)
    expect(prov.faltante).to eq(18) # sigue faltando comprar 18
  end

  it 'no reserva nada del ítem sin stock, pero sí de los que tienen' do
    otro = create(:bar_producto, club: club, bar: bar, nombre: 'Agua', stock: 0, costo_ars: 100)
    proveer(10)
    post path, params: { bar_producto_id: otro.id, cantidad_prevista: 5 }, headers: auth_headers, as: :json

    post path('/reservar'), headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(cerveza.reload.stock).to eq(20) # el que tenía stock se reservó igual
    expect(otro.reload.stock).to eq(0)

    body = JSON.parse(response.body)
    expect(body['advertencias'].join).to include('Agua', 'sin stock disponible')
    expect(evento.provisiones.find_by(provisionable: otro).cantidad_reservada).to eq(0)
  end

  it 'reserva descontando del depósito cuando alcanza' do
    proveer(20) # hay 30 → alcanza
    post path('/reservar'), headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(cerveza.reload.stock).to eq(10) # 30 - 20 reservadas
    prov = evento.provisiones.first
    expect(prov.cantidad_reservada).to eq(20)
    expect(cerveza.bar_stock_movimientos.where(tipo: 'reserva_evento').count).to eq(1)
  end

  it 'al cerrar, el sobrante vuelve al depósito' do
    proveer(20)
    post path('/reservar'), headers: auth_headers, as: :json
    prov = evento.provisiones.first
    # reservó 20 (depósito 10). Se consumieron 14 → sobran 6 → vuelven (depósito 16)
    post path('/cerrar'), params: { consumos: [{ id: prov.id, cantidad_consumida: 14 }], finalizar: true },
         headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(cerveza.reload.stock).to eq(16) # 10 + 6 devueltos
    expect(prov.reload.cantidad_consumida).to eq(14)
    expect(evento.reload.estado).to eq('finalizado')
    expect(cerveza.bar_stock_movimientos.where(tipo: 'devolucion_evento').last.cantidad).to eq(6)
  end
end
