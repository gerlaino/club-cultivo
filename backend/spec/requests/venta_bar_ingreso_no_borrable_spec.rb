require 'rails_helper'

# El ingreso de una venta del salón NO se borra desde el libro: si se borrara solo el asiento, la
# venta seguiría existiendo y la mercadería NO volvería al depósito (el stock salió al cobrar).
# La venta es el único lugar donde se deshace, y ahí se revierten las dos cosas.
RSpec.describe 'Ingreso de venta del bar — solo se borra por la venta', type: :request do
  let(:club)  { create(:club, features: { 'bar' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:bar)   { create(:barra, club: club, sede: sede) }
  let!(:cerveza) { create(:bar_producto, club: club, bar: bar, nombre: 'Cerveza', stock: 20, precio_ars: 2500) }

  def cobrar_una(cantidad: 2)
    ActsAsTenant.with_tenant(club) do
      ::Bar::RegistrarVenta.new(
        bar, admin,
        lineas: [{ vendible_type: 'BarProducto', vendible_id: cerveza.id, cantidad: cantidad }],
        medio_pago: 'efectivo'
      ).call
    end
  end

  before { sign_in_as(admin) }

  it 'rechaza borrar el asiento de la venta desde contabilidad y no toca el stock' do
    venta = cobrar_una
    expect(cerveza.reload.stock.to_d).to eq(18)

    delete "/api/movimientos_contables/#{venta.movimiento_contable_id}", as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to include("venta ##{venta.id}")
    expect(MovimientoContable.exists?(venta.movimiento_contable_id)).to be(true)
    expect(cerveza.reload.stock.to_d).to eq(18)
  end

  it 'al borrar la venta devuelve el stock y saca el ingreso del libro' do
    venta = cobrar_una
    mov_id = venta.movimiento_contable_id

    delete "/bares/#{bar.id}/ventas/#{venta.id}", as: :json

    expect(response).to have_http_status(:no_content)
    expect(cerveza.reload.stock.to_d).to eq(20)
    expect(MovimientoContable.exists?(mov_id)).to be(false)
  end

  it 'un dispensador no puede borrar ventas' do
    venta = cobrar_una
    sign_in_as(create(:user, :dispensador, club: club))

    delete "/bares/#{bar.id}/ventas/#{venta.id}", as: :json

    expect(response).to have_http_status(:forbidden)
    expect(cerveza.reload.stock.to_d).to eq(18)
  end
end
