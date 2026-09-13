require 'rails_helper'

# AGOTADO ≠ SACADO (pedido de Germán, sep-2026). Un producto que se terminó atendiendo desaparecía
# de la lista y quien atiende no sabía si se había acabado o si nunca estuvo. Ahora sigue en
# cero: con producto en el depósito, con el botón de reposición; sin producto, deshabilitado y
# diciéndolo. Lo que administración bajó a propósito sí se va de la lista.
RSpec.describe 'Lo que se agotó sobre la mesa', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:ana)      { create(:user, :dispensador, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'mixta') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  # 20 g en total: 10 sobre la mesa y 10 en el depósito.
  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 20, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  before do
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'carga',
                               cambios: [{ stock_id: stock.id, cantidad: 10 }])
      Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: ana, efectivo_contado_ars: 1000)
    end
  end

  def dispensar!(gramos)
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: ana, stock: stock, sede: sede, cantidad: gramos,
                           medio_pago: 'efectivo', aporte_socio_ars: gramos * 100, fecha_dispensacion: Time.zone.today)
    end
  end

  def mostrador
    sign_in_as(ana)
    get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers
    JSON.parse(response.body)
  end

  it 'lo que se terminó dispensando sigue en la lista, en cero, y se puede pedir' do
    dispensar!(10)

    datos = mostrador
    expect(datos['mesa']).to be_empty
    fila = datos['agotados'].find { |a| a['stock_id'] == stock.id }
    expect(fila).to include('mostrador' => 0.0, 'agotado' => true, 'hay_en_deposito' => true, 'reposicion_pedida' => false)
  end

  it 'si tampoco queda en el depósito, lo dice' do
    stock.update_column(:cantidad, 10)   # sólo lo que estaba arriba
    dispensar!(10)

    fila = mostrador['agotados'].find { |a| a['stock_id'] == stock.id }
    expect(fila['hay_en_deposito']).to be(false)
  end

  it 'lo que administración bajó a propósito NO es un agotado' do
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'vuelve al depósito',
                               cambios: [{ stock_id: stock.id, cantidad: 0 }])
    end

    expect(mostrador['agotados']).to be_empty
  end

  it 'lo agotado no entra al arqueo ni a la mesa que se cuenta' do
    dispensar!(10)

    expect(mesa_de(sede)).not_to have_key(stock.id)
  end
end
