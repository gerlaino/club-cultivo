require 'rails_helper'

# Contabilidad de caja con deuda visible (2026-06):
# - Ingreso real (pagado: true) solo cuando entra plata: efectivo/transferencia.
# - Dispensación a crédito (cuenta_corriente/no_abona) → movimiento pagado: false
#   (deuda visible, excluido de los totales de ingresos) + débito de CC.
# - Pagar en efectivo NUNCA debita la CC, aunque el paciente tenga límite configurado.
# - El asiento de una dispensación vive y muere con ella, y no se edita a mano.
RSpec.describe 'Contabilidad de caja', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc) do
    CuentaCorriente.create!(
      paciente: paciente, club: club,
      saldo_disponible: 0, limite_credito: 50_000
    )
  end
  let!(:stock) do
    Stock.create!(
      sede: sede, lote: lote,
      origen: 'lote', forma_producto: 'flor_seca',
      unidad: 'g', cantidad: 200
    )
  end

  before { sign_in_as(admin) }

  def dispensar(medio_pago:, aporte: 5_000, cantidad: 5)
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: {
           dispensacion: {
             stock_id:           stock.id,
             cantidad:           cantidad,
             aporte_socio_ars:   aporte,
             medio_pago:         medio_pago,
             fecha_dispensacion: Date.today.to_s,
           }
         },
         headers: auth_headers,
         as: :json
  end

  context 'dispensación en efectivo' do
    it 'crea el movimiento contable como pagado (plata real)' do
      dispensar(medio_pago: 'efectivo')
      expect(response).to have_http_status(:created)
      mov = MovimientoContable.last
      expect(mov.pagado).to be(true)
      expect(mov.tipo).to eq('recupero_costo')
    end

    it 'NO debita la cuenta corriente aunque haya límite configurado' do
      expect { dispensar(medio_pago: 'efectivo') }
        .not_to change { cc.reload.saldo_disponible }
      expect(cc.movimientos.where(tipo: 'debito')).to be_empty
    end

    it 'el ingreso entra en los totales del libro' do
      dispensar(medio_pago: 'efectivo')
      expect(MovimientoContable.ingresos.sum(:monto_ars)).to eq(5_000)
      expect(MovimientoContable.a_credito.sum(:monto_ars)).to eq(0)
    end
  end

  context 'dispensación a crédito (cuenta_corriente)' do
    it 'crea el movimiento como NO pagado (deuda visible)' do
      dispensar(medio_pago: 'cuenta_corriente')
      expect(response).to have_http_status(:created)
      expect(MovimientoContable.last.pagado).to be(false)
    end

    it 'debita la cuenta corriente' do
      expect { dispensar(medio_pago: 'cuenta_corriente') }
        .to change { cc.reload.saldo_disponible }.by(-5_000)
    end

    it 'NO suma a los ingresos (evita el doble conteo con el aporte posterior)' do
      dispensar(medio_pago: 'cuenta_corriente')
      expect(MovimientoContable.ingresos.sum(:monto_ars)).to eq(0)
      expect(MovimientoContable.a_credito.sum(:monto_ars)).to eq(5_000)
    end
  end

  context 'eliminación de la dispensación' do
    it 'elimina también su movimiento contable (sin ingresos huérfanos)' do
      dispensar(medio_pago: 'efectivo')
      dispensacion = Dispensacion.last
      expect {
        delete "/dispensaciones/#{dispensacion.id}", headers: auth_headers, as: :json
      }.to change(MovimientoContable, :count).by(-1)
    end
  end

  context 'movimientos generados por dispensación' do
    before { dispensar(medio_pago: 'efectivo') }
    let(:mov) { MovimientoContable.last }

    it 'no se pueden editar por API' do
      patch "/movimientos_contables/#{mov.id}",
            params: { movimiento_contable: { monto_ars: 999 } },
            headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(mov.reload.monto_ars).to eq(5_000)
    end

    it 'no se pueden borrar por API' do
      expect {
        delete "/movimientos_contables/#{mov.id}", headers: auth_headers, as: :json
      }.not_to change(MovimientoContable, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'aporte de socio (pago de deuda)' do
    def crear_aporte(monto: 5_000)
      post '/movimientos_contables',
           params: {
             movimiento_contable: {
               tipo: 'ingreso', categoria: 'aporte_socio',
               descripcion: 'Pago de deuda', monto_ars: monto,
               fecha: Date.today.to_s, sede_id: sede.id, paciente_id: paciente.id,
             }
           },
           headers: auth_headers, as: :json
    end

    it 'acredita la cuenta corriente del socio' do
      expect { crear_aporte }.to change { cc.reload.saldo_disponible }.by(5_000)
    end

    it 'al eliminarlo se revierte el crédito (sin crédito fantasma)' do
      crear_aporte
      mov = MovimientoContable.last
      expect {
        delete "/movimientos_contables/#{mov.id}", headers: auth_headers, as: :json
      }.to change { cc.reload.saldo_disponible }.by(-5_000)
      expect(response).to have_http_status(:no_content)
    end

    it 'bloquea cambiarle el monto (libro y crédito quedarían desincronizados)' do
      crear_aporte
      mov = MovimientoContable.last
      patch "/movimientos_contables/#{mov.id}",
            params: { movimiento_contable: { monto_ars: 1 } },
            headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
