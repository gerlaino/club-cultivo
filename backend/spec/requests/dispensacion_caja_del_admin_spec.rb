require 'rails_helper'

# A QUÉ CAJA VA LA PLATA CUANDO DISPENSA ADMINISTRACIÓN (decisión de Germán, sep-2026).
#
# El cobro caía SIEMPRE en la caja abierta de la sede, sin preguntar: el admin vendía del depósito,
# se guardaba la plata, y a la noche el arqueo del dispensador esperaba $X que nunca entraron al
# cajón. La diferencia quedaba anotada a nombre de quien no la produjo.
#
#   · Si algo del carrito está SOBRE LA MESA, va a la caja de ese mostrador, sin elegir.
#   · Si todo sale del depósito, va a la caja que eligió — o a ninguna, si no eligió.
#   · Quien atiende sigue como siempre: cobra en la suya.
RSpec.describe 'La caja de un cobro de administración', type: :request do
  include AuthHelpers

  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:ana)    { create(:user, :dispensador, club: club) }
  let(:sede)   { create(:sede, club: club, tipo: 'mixta', nombre: 'Centro') }
  let(:norte)  { create(:sede, club: club, tipo: 'social', nombre: 'Norte') }
  let(:sala)   { ActsAsTenant.with_tenant(club) { create(:sala, club: club, sede: sede) } }
  let(:lote)   { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: sala) } }
  let(:pac)    { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }
  # Uno sobre la mesa de Centro, otro sólo en el depósito de Centro.
  let!(:en_mesa)   { ActsAsTenant.with_tenant(club) { create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', cantidad: 100, precio_sugerido_ars: 100) } }
  let!(:deposito)  { ActsAsTenant.with_tenant(club) { create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'hash', cantidad: 50, precio_sugerido_ars: 200) } }

  let!(:turno_centro) do
    ActsAsTenant.with_tenant(club) do
      m = sede.mostrador!
      Mostradores::Cargar.call(mostrador: m, usuario: admin, motivo: 'del día', cambios: [{ stock_id: en_mesa.id, cantidad: 40 }])
      Mostradores::AbrirCaja.call(mostrador: m, usuario: ana, efectivo_contado_ars: 1_000).turno
    end
  end
  let!(:turno_norte) do
    ActsAsTenant.with_tenant(club) do
      Mostradores::AbrirCaja.call(mostrador: norte.mostrador!, usuario: admin, efectivo_contado_ars: 500).turno
    end
  end

  def dispensar(como:, items:, caja: nil)
    sign_in_as(como)
    post "/api/pacientes/#{pac.id}/dispensaciones", headers: auth_headers,
         params: { dispensacion: { medio_pago: 'efectivo', sede_id: sede.id, caja_turno_id: caja,
                                   items: items.map { |st, c| { stock_id: st.id, cantidad: c } } } }
    expect(response).to have_http_status(:created), response.body
    Dispensacion.unscoped.find(JSON.parse(response.body)['id'])
  end

  # Con un solo medio de pago el modal no mandaba `cobros`, la dispensa tomaba el camino legacy y
  # no creaba ningún `Cobro`: la venta simple en efectivo no entraba a ningún arqueo.
  it 'una venta simple en efectivo crea su cobro y entra al arqueo' do
    dispensar(como: ana, items: { en_mesa => 5 })
    expect(turno_centro.caja_turno.reload.efectivo_esperado_ars).to eq(1_500.0)
  end

  it 'lo que sale de la mesa cae en la caja de ese mostrador, sin elegir' do
    d = dispensar(como: admin, items: { en_mesa => 5 }, caja: turno_norte.caja_turno_id)
    expect(d.cobros.first.caja_turno_id).to eq(turno_centro.caja_turno_id)
  end

  it 'lo que sale del depósito cae en la caja que eligió' do
    d = dispensar(como: admin, items: { deposito => 5 }, caja: turno_norte.caja_turno_id)
    expect(d.cobros.first.caja_turno_id).to eq(turno_norte.caja_turno_id)
  end

  it 'sin elegir, no entra a ningún mostrador — y el asiento se escribe igual' do
    d = dispensar(como: admin, items: { deposito => 5 })
    expect(d.cobros.first.caja_turno_id).to be_nil
    expect(MovimientoContable.unscoped.where(dispensacion_id: d.id).count).to be >= 1
  end

  it 'una caja cerrada o ajena no vale como elección' do
    ActsAsTenant.with_tenant(club) { Mostradores::CerrarCaja.call(turno: turno_norte, usuario: admin, efectivo_contado_ars: 500) }
    d = dispensar(como: admin, items: { deposito => 5 }, caja: turno_norte.caja_turno_id)
    expect(d.cobros.first.caja_turno_id).to be_nil
  end

  it 'quien atiende cobra en su caja, elija lo que elija' do
    d = dispensar(como: ana, items: { en_mesa => 5 }, caja: turno_norte.caja_turno_id)
    expect(d.cobros.first.caja_turno_id).to eq(turno_centro.caja_turno_id)
  end

  # Administración dispensa contra depósito + mesa. Con 40 arriba y 50 en la línea, restar la
  # línea entera dejaba la mesa en negativo y la dispensa rebotaba con «No hay tanto sobre la mesa».
  it 'con más de lo que hay arriba, baja la mesa a cero y el resto sale del depósito' do
    d = dispensar(como: admin, items: { en_mesa => 50 })
    mi = ActsAsTenant.with_tenant(club) { sede.mostrador.items.find_by(stock_id: en_mesa.id) }
    expect(mi.cantidad).to eq(0)
    expect(en_mesa.reload.cantidad).to eq(50)
    expect(d.cobros.first.caja_turno_id).to eq(turno_centro.caja_turno_id)
  end
end
