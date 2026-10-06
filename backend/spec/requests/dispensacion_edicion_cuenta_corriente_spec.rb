require 'rails_helper'

# AC (Javi y Germán, 6-oct-2026 — la dispensa #838 de Martín Blanco):
# · Si el paciente paga MENOS que el total, la diferencia se ajusta con la cuenta corriente,
#   también al EDITAR una dispensa (antes la edición sólo aceptaba un medio por el total, y la
#   única salida era bajar el precio, que es un descuento).
# · Si lo que no paga no entra en el cupo, se rechaza (como el «Paga con» de la creación).
#   «Cuenta corriente» a secas mantiene la regla vieja: cubre hasta el cupo y el resto se asienta
#   cobrado en el momento (dispensacion_descuentos_credito_spec).
# · El detalle de la dispensa coincide con su total.
RSpec.describe 'Editar una dispensa: lo que no paga va a la cuenta corriente', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  # 100 g a $1.710 = $171.000, como la dispensa de Martín.
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 500, precio_sugerido_ars: 1710) }
  let(:items)    { [{ stock_id: stock.id, cantidad: 100 }] }

  def cuenta(saldo:, limite:)
    paciente.cuenta_corriente!.tap { |c| c.update!(saldo_disponible: saldo, limite_credito: limite) }
  end

  def dispensa_en_efectivo
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { medio_pago: 'efectivo', items: items } }, headers: auth_headers
    expect(response).to have_http_status(:created)
    Dispensacion.last
  end

  def editar(d, **extra)
    patch "/dispensaciones/#{d.id}", params: { dispensacion: { items: items }.merge(extra) }, headers: auth_headers
  end

  def suma_lineas(d) = d.items.reload.sum { |it| (it.cantidad.to_d * it.precio_unitario_ars.to_d) }.round

  before { sign_in_as(admin) }

  describe 'paga una parte y el resto queda debiendo' do
    it 'pagó $80.000 por transferencia: el total sigue en $171.000 y los $91.000 van a la cuenta corriente' do
      cc = cuenta(saldo: -154_500, limite: 300_000)
      d  = dispensa_en_efectivo

      editar(d, medio_pago: 'transferencia', cobros: [{ medio: 'transferencia', monto: 80_000 }])

      expect(response).to have_http_status(:ok)
      d.reload
      expect(d.aporte_socio_ars).to eq(171_000)
      expect(d.cobros.pluck(:medio, :monto_ars).to_h { |m, v| [m, v.to_d] })
        .to eq('transferencia' => 80_000, 'cuenta_corriente' => 91_000)
      expect(cc.reload.saldo_disponible).to eq(-154_500 - 91_000)
      expect(suma_lineas(d)).to eq(171_000)
    end

    it 'la misma dispensa se puede volver a editar: se rehacen los cobros y la cuenta corriente no se duplica' do
      cc = cuenta(saldo: 0, limite: 300_000)
      d  = dispensa_en_efectivo
      editar(d, medio_pago: 'transferencia', cobros: [{ medio: 'transferencia', monto: 80_000 }])
      editar(d, medio_pago: 'transferencia', cobros: [{ medio: 'transferencia', monto: 100_000 }])

      expect(response).to have_http_status(:ok)
      expect(d.reload.cobros.pluck(:medio, :monto_ars).to_h { |m, v| [m, v.to_d] })
        .to eq('transferencia' => 100_000, 'cuenta_corriente' => 71_000)
      expect(cc.reload.saldo_disponible).to eq(-71_000)
    end

    it 'si paga de más, lo que sobra queda a favor' do
      cc = cuenta(saldo: 0, limite: 0)
      d  = dispensa_en_efectivo
      editar(d, medio_pago: 'efectivo', cobros: [{ medio: 'efectivo', monto: 180_000 }])

      expect(response).to have_http_status(:ok)
      expect(cc.reload.saldo_disponible).to eq(9_000)
    end
  end

  describe 'cuando no alcanza el cupo' do
    it 'si los $91.000 no entran en el cupo, se rechaza diciendo cuánto falta y no cambia nada' do
      cc = cuenta(saldo: -154_500, limite: 200_000) # cupo libre: $45.500
      d  = dispensa_en_efectivo
      antes = cc.reload.saldo_disponible

      editar(d, medio_pago: 'transferencia', cobros: [{ medio: 'transferencia', monto: 80_000 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('Crédito insuficiente')
      expect(cc.reload.saldo_disponible).to eq(antes)
      expect(d.reload.cobros.pluck(:medio, :monto_ars).to_h { |m, v| [m, v.to_d] }).to eq('efectivo' => 171_000)
    end

    it 'editar a «cuenta corriente» a secas mantiene la regla de la creación: cubre hasta el cupo y el resto se cobra' do
      cc = cuenta(saldo: -154_500, limite: 200_000) # cupo libre: $45.500
      d  = dispensa_en_efectivo

      editar(d, medio_pago: 'cuenta_corriente')

      expect(response).to have_http_status(:ok)
      expect(d.reload.monto_credito_ars).to eq(45_500)
      expect(cc.reload.saldo_disponible).to eq(-200_000)
    end

    it 'si entra en el cupo, «cuenta corriente» carga el total entero' do
      cc = cuenta(saldo: 0, limite: 200_000)
      d  = dispensa_en_efectivo
      editar(d, medio_pago: 'cuenta_corriente')

      expect(response).to have_http_status(:ok)
      expect(cc.reload.saldo_disponible).to eq(-171_000)
    end
  end

  # Los errores silenciosos que la edición NO puede cometer (6-oct-2026, Germán: «no podemos errar
  # en estos detalles»). En cada caso: se rechaza con el motivo y no se mueve nada.
  describe 'lo que no puede pasar en silencio' do
    def pagar_parcial(d, pago)
      editar(d, medio_pago: 'transferencia', cobros: [{ medio: 'transferencia', monto: pago }])
      expect(response).to have_http_status(:ok)
    end

    def sin_cambios!(d, cc, cobros, saldo)
      expect(cc.reload.saldo_disponible).to eq(saldo)
      expect(d.reload.cobros.pluck(:medio, :monto_ars).to_h { |m, v| [m, v.to_d] }).to eq(cobros)
    end

    it 'si tenía una parte a cuenta corriente y la edición no dice cuánto pagó, no la convierte en «pagó todo»' do
      cc = cuenta(saldo: 0, limite: 300_000)
      d  = dispensa_en_efectivo
      pagar_parcial(d, 80_000)

      editar(d, medio_pago: 'transferencia') # sin «Paga con»

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('parte a cuenta corriente')
      sin_cambios!(d, cc, { 'transferencia' => 80_000, 'cuenta_corriente' => 91_000 }, -91_000)
    end

    it 'con deuda previa, cambiar la cantidad diciendo lo que pagó recalcula la deuda sobre el total nuevo' do
      cc = cuenta(saldo: 0, limite: 300_000)
      d  = dispensa_en_efectivo
      pagar_parcial(d, 80_000)

      patch "/dispensaciones/#{d.id}", headers: auth_headers, params: { dispensacion: {
        items: [{ stock_id: stock.id, cantidad: 60 }], medio_pago: 'transferencia',
        cobros: [{ medio: 'transferencia', monto: 80_000 }] } }

      expect(response).to have_http_status(:ok)
      expect(d.reload.aporte_socio_ars).to eq(102_600)                    # 60 g × $1.710
      expect(cc.reload.saldo_disponible).to eq(-22_600)                   # 102.600 − 80.000
    end

    it 'si se pagó en parte con saldo a favor, no deja cambiar el monto (se cobraría en efectivo lo que salió del saldo)' do
      cc = cuenta(saldo: 10_000, limite: 0)
      d  = dispensa_en_efectivo # usa los $10.000 a favor + $161.000 en efectivo
      expect(d.cobros.pluck(:medio)).to include('saldo_a_favor')

      editar(d, medio_pago: 'efectivo')

      expect(response).to have_http_status(:unprocessable_entity)
      sin_cambios!(d, cc, { 'saldo_a_favor' => 10_000, 'efectivo' => 161_000 }, 0)
    end

    it 'si se pagó con dos medios, no deja cambiar el monto' do
      cc = cuenta(saldo: 0, limite: 0)
      post "/pacientes/#{paciente.id}/dispensaciones", headers: auth_headers, params: { dispensacion: {
        medio_pago: 'efectivo', items: items,
        cobros: [{ medio: 'efectivo', monto: 100_000 }, { medio: 'transferencia', monto: 71_000 }] } }
      d = Dispensacion.last

      editar(d, medio_pago: 'efectivo')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('dos medios')
      sin_cambios!(d, cc, { 'efectivo' => 100_000, 'transferencia' => 71_000 }, 0)
    end

    it 'si la plata ya entró en un cierre de caja, no deja cambiar el monto (movería un arqueo firmado)' do
      cc = cuenta(saldo: 0, limite: 300_000)
      d  = dispensa_en_efectivo
      caja = CajaTurno.new(club: club, sede: sede, abierta_por: admin, estado: 'cerrada',
                           abierta_at: 1.day.ago, cerrada_at: 1.hour.ago)
      caja.save!(validate: false)
      d.cobros.update_all(caja_turno_id: caja.id)

      editar(d, medio_pago: 'transferencia', cobros: [{ medio: 'transferencia', monto: 80_000 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('cierre de caja')
      sin_cambios!(d, cc, { 'efectivo' => 171_000 }, 0)
    end
  end
end
