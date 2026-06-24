require 'rails_helper'

RSpec.describe 'Dispensaciones con cobros (pagos partidos / contra-entrega)', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:delivery)    { create(:user, club: club, role: 'delivery') }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin, telefono: '1', domicilio_calle: 'Calle', domicilio_ciudad: 'CABA') }
  # Precio tal que aporte_socio_ars = 100.000 (cantidad 1)
  let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 1000, precio_sugerido_ars: 100_000) }

  def crear(cobros: nil, cobrar_en_entrega: nil, **extra)
    body = { stock_id: stock.id, cantidad: 1 }
    body[:cobros] = cobros if cobros
    body[:cobrar_en_entrega] = cobrar_en_entrega unless cobrar_en_entrega.nil?
    body.merge!(extra)
    post "/pacientes/#{paciente.id}/dispensaciones", params: { dispensacion: body }, headers: auth_headers
  end

  context 'pago partido: paga $40.000 y el resto a cuenta corriente' do
    let!(:cc) { create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 80_000) }

    it 'crea la dispensa saldada, con cobro efectivo + el resto en cuenta corriente' do
      sign_in_as(dispensador)
      crear(cobros: [{ medio: 'efectivo', monto: 40_000 }])
      expect(response).to have_http_status(:created)
      d = Dispensacion.last
      expect(d.aporte_socio_ars).to eq(100_000)
      expect(d.saldo_pendiente).to eq(0)
      expect(d.cobros.pagados.sum(:monto_ars)).to eq(40_000)
      expect(d.cobros.a_credito.sum(:monto_ars)).to eq(60_000)
      expect(cc.reload.saldo_disponible).to eq(-60_000)
      expect(d.medio_pago).to eq('mixto')
    end
  end

  context 'bloqueo: el resto supera el cupo' do
    let!(:cc) { create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 50_000) }

    it 'rechaza (422) si paga poco y el resto no entra en el cupo' do
      sign_in_as(dispensador)
      crear(cobros: [{ medio: 'efectivo', monto: 40_000 }])   # resto 60.000 > cupo 50.000
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Dispensacion.count).to eq(0)   # rollback total
    end
  end

  context 'contra-entrega: el delivery cobra al entregar' do
    let!(:cc) { create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 80_000) }

    it 'crea sin cobros (saldo = total) y el delivery cobra efectivo + resto a cuenta' do
      sign_in_as(dispensador)
      crear(cobrar_en_entrega: true, con_envio: true, delivery_id: delivery.id, usar_domicilio_paciente: true)
      expect(response).to have_http_status(:created)
      d = Dispensacion.last
      expect(d.cobrar_en_entrega).to be true
      expect(d.saldo_pendiente).to eq(100_000)
      expect(d.cobros).to be_empty

      delete '/api/users/sign_out'
      sign_in_as(delivery)
      patch "/dispensaciones/#{d.id}/entregar",
            params: { cobros: [{ medio: 'efectivo', monto: 30_000 }], notas_entrega: 'OK' },
            headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(d.reload.estado_envio).to eq('entregado')
      expect(d.saldo_pendiente).to eq(0)
      expect(d.cobros.a_credito.sum(:monto_ars)).to eq(70_000)
      expect(cc.reload.saldo_disponible).to eq(-70_000)
    end
  end

  context 'cancelación revierte los cobros y la cuenta corriente' do
    let!(:cc) { create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 80_000) }

    it 'al cancelar, se borran los cobros y se revierte la deuda' do
      sign_in_as(dispensador)
      crear(cobros: [{ medio: 'efectivo', monto: 40_000 }])   # resto 60.000 a cuenta
      d = Dispensacion.last
      expect(cc.reload.saldo_disponible).to eq(-60_000)

      delete '/api/users/sign_out'
      sign_in_as(admin)
      patch "/dispensaciones/#{d.id}/cancelar_entrega", params: { motivo: 'test' }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(d.reload.estado_envio).to eq('cancelada')
      expect(d.cobros).to be_empty
      expect(cc.reload.saldo_disponible).to eq(0)   # deuda revertida
    end
  end
end
