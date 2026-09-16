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

    # UNA PARTE AHORA Y EL RESTO EN LA PUERTA (decisión de Germán, sep-2026): la transferencia que
    # ya entró se asienta al crear, y el repartidor ve sólo el saldo. Antes «contra entrega» era
    # todo o nada: con el flag puesto no se registraba ningún cobro.
    it 'con una parte ya paga, la asienta ahora y el repartidor cobra sólo el resto' do
      sign_in_as(dispensador)
      crear(cobros: [{ medio: 'transferencia', monto: 60_000 }], cobrar_en_entrega: true,
            con_envio: true, delivery_id: delivery.id, usar_domicilio_paciente: true)
      expect(response).to have_http_status(:created), response.body
      d = Dispensacion.last
      expect(d.cobros.pluck(:medio, :monto_ars)).to eq([['transferencia', 60_000]])
      expect(d.saldo_pendiente).to eq(40_000)
      expect(d.cobros.a_credito).to be_empty   # el resto NO fue a cuenta corriente
      expect(d.medio_pago).to eq('transferencia')

      delete '/api/users/sign_out'
      sign_in_as(delivery)
      patch "/dispensaciones/#{d.id}/entregar",
            params: { cobros: [{ medio: 'efectivo', monto: 40_000 }], notas_entrega: 'OK' }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(d.reload.saldo_pendiente).to eq(0)
      expect(d.medio_pago).to eq('mixto')
      expect(cc.reload.saldo_disponible).to eq(0)
    end

    it 'si lo cobrado ahora cubre el total, contra entrega no tiene sentido y lo dice' do
      sign_in_as(dispensador)
      crear(cobros: [{ medio: 'transferencia', monto: 100_000 }], cobrar_en_entrega: true,
            con_envio: true, delivery_id: delivery.id, usar_domicilio_paciente: true)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/cubre el total/)
      expect(Dispensacion.count).to eq(0)
    end

    it 'acepta los cobros en forma de hash (multipart, cuando se sube foto)' do
      sign_in_as(dispensador)
      crear(cobrar_en_entrega: true, con_envio: true, delivery_id: delivery.id, usar_domicilio_paciente: true)
      d = Dispensacion.last
      delete '/api/users/sign_out'
      sign_in_as(delivery)
      # Multipart manda cobros[0][medio]/[monto] → en el backend llegan como {"0" => {...}}
      patch "/dispensaciones/#{d.id}/entregar",
            params: { cobros: { '0' => { medio: 'efectivo', monto: 100_000 } }, notas_entrega: 'OK' },
            headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(d.reload.estado_envio).to eq('entregado')
      expect(d.saldo_pendiente).to eq(0)
    end
  end

  # SE PUEDE PAGAR DE MÁS SÓLO PARA BAJAR DEUDA (Germán, 16-sep-2026): dejar plata «a favor» al
  # cobrar es que el club se quede con plata del paciente por accidente. Para adelantar plata
  # está «Cargar crédito» en la ficha.
  context 'sobrepago: el socio paga de más' do
    it 'con deuda en cuenta corriente: cubre la dispensa y lo de más baja la deuda' do
      cc = create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: -20_000, limite_credito: 80_000)
      sign_in_as(dispensador)
      crear(cobros: [{ medio: 'efectivo', monto: 120_000 }])   # total 100.000 → 20.000 de más
      expect(response).to have_http_status(:created)
      d = Dispensacion.last
      expect(d.saldo_pendiente).to eq(0)
      expect(d.cobros.sum(:monto_ars)).to eq(100_000)          # los cobros no superan el total
      expect(cc.reload.saldo_disponible).to eq(0)               # debía 20.000, quedó en cero
      # La plata ENTRÓ: queda en el libro como «Aporte socio» —el mismo asiento que «Registrar
      # pago»—, atado a la dispensa y con el medio con el que pagó. (Hasta sep-2026 no había
      # asiento: el libro decía 100.000 habiendo entrado 120.000, y la caja cerraba con un
      # sobrante que nadie podía explicar.)
      aporte = MovimientoContable.where(dispensacion: d, categoria: 'aporte_socio')
      expect(aporte.count).to eq(1)
      expect(aporte.first.monto_ars).to eq(20_000)
      expect(aporte.first.medio_pago).to eq('efectivo')
      # El asiento de la dispensa sigue siendo el de la dispensa: 100.000, no 120.000.
      expect(MovimientoContable.where(dispensacion: d, categoria: 'dispensacion').sum(:monto_ars)).to eq(100_000)
      # Y la CC quedó acreditada una sola vez (por el asiento, no a mano).
      expect(cc.movimientos.where(tipo: 'pago').sum(:monto)).to eq(20_000)
    end

    # «Efectivo 30.000 + cuenta corriente 10.000» sobre 30.000 no significa nada: la cuenta
    # corriente cubre lo que falta. Pasó en producción y acreditaba plata que nadie puso.
    it 'la cuenta corriente no puede ser la línea que sobra' do
      create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: -50_000, limite_credito: 80_000)
      sign_in_as(dispensador)
      crear(cobros: [{ medio: 'efectivo', monto: 100_000 }, { medio: 'cuenta_corriente', monto: 10_000 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body).values.flatten.join).to include('cuenta corriente sólo cubre lo que falta')
      expect(Dispensacion.count).to eq(0)
    end

    it 'con deuda: al cancelar, la deuda vuelve' do
      cc = create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: -20_000, limite_credito: 80_000)
      sign_in_as(dispensador)
      crear(cobros: [{ medio: 'efectivo', monto: 120_000 }])
      d = Dispensacion.last
      expect(cc.reload.saldo_disponible).to eq(0)

      delete '/api/users/sign_out'
      sign_in_as(admin)
      patch "/dispensaciones/#{d.id}/cancelar_entrega", params: { motivo: 'test' }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(cc.reload.saldo_disponible).to eq(-20_000)   # el aporte se revirtió con la dispensa
    end

    it 'sin deuda: no se puede pagar de más, y lo dice' do
      create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 80_000)
      sign_in_as(dispensador)
      crear(cobros: [{ medio: 'efectivo', monto: 120_000 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body).values.flatten.join).to include('no debe nada')
      expect(Dispensacion.count).to eq(0)
    end

    it 'con menos deuda que lo pagado de más: rebota diciendo hasta cuánto' do
      create(:cuenta_corriente, paciente: paciente, club: club, saldo_disponible: -5_000, limite_credito: 80_000)
      sign_in_as(dispensador)
      crear(cobros: [{ medio: 'efectivo', monto: 120_000 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body).values.flatten.join).to include('sólo debe $5.000')
    end

    it 'sin cuenta corriente: bloquea (no hay dónde acreditar el excedente)' do
      sign_in_as(dispensador)
      crear(cobros: [{ medio: 'efectivo', monto: 120_000 }])
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Dispensacion.count).to eq(0)
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
