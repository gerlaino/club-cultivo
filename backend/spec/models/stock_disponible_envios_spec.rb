require 'rails_helper'

# Regresión: un envío pendiente descuenta el stock UNA sola vez. Antes se restaba dos veces
# (decrementar_stock + gramos_reservados), dejando el disponible en ~0 y bloqueando la 2da dispensa.
RSpec.describe 'Stock#cantidad_disponible_real con envíos pendientes', type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: create(:sala, club: club, sede: sede, created_by: admin)) }
  let(:pac)   { create(:paciente, club: club, created_by: admin, email: 'p@g.com') }
  let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 10) }

  def envio(cant)
    Dispensacion.create!(paciente: pac, user: admin, stock: stock, sede: sede, cantidad: cant,
                         medio_pago: 'efectivo', fecha_dispensacion: Date.today, aporte_socio_ars: cant * 10,
                         con_envio: true, estado_envio: 'pendiente', direccion_envio: 'C 1', contacto_nombre: 'P')
  end

  it 'no descuenta dos veces: tras un envío de 60g quedan 40g disponibles' do
    envio(60)
    stock.reload
    expect(stock.cantidad.to_f).to eq(40.0)
    expect(stock.cantidad_disponible_real.to_f).to eq(40.0) # antes daba 0 (doble descuento)
  end

  it 'permite una segunda dispensación dentro de lo disponible y rechaza la que excede' do
    envio(60) # quedan 40
    ok    = Dispensacion.new(paciente: pac, user: admin, stock: stock, sede: sede, cantidad: 30,
                             medio_pago: 'efectivo', fecha_dispensacion: Date.today, aporte_socio_ars: 300)
    nope  = Dispensacion.new(paciente: pac, user: admin, stock: stock, sede: sede, cantidad: 50,
                             medio_pago: 'efectivo', fecha_dispensacion: Date.today, aporte_socio_ars: 500)
    expect(ok.valid?).to be true
    expect(nope.valid?).to be false
    expect(nope.errors[:cantidad].join).to match(/stock disponible/)
  end
end
