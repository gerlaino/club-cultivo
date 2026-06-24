require 'rails_helper'

RSpec.describe 'Reservas', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin,       club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:cultivador)  { create(:user, :cultivador,  club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin) }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin) }

  let!(:stock) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote',
                  forma_producto: 'flor_seca', unidad: 'g', cantidad: 100,
                  precio_sugerido_ars: 100)
  end

  describe 'POST /pacientes/:paciente_id/reservas' do
    before { sign_in_as(dispensador) }

    it 'crea una reserva pendiente y bloquea el stock' do
      post "/pacientes/#{paciente.id}/reservas",
           params: { reserva: { stock_id: stock.id, cantidad: 30, fecha_entrega_estimada: 3.days.from_now.to_date } },
           headers: auth_headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['estado']).to eq('pendiente')
      expect(stock.reload.gramos_reservados).to eq(30.0)
    end

    it 'rechaza si supera el disponible' do
      post "/pacientes/#{paciente.id}/reservas",
           params: { reserva: { stock_id: stock.id, cantidad: 999, fecha_entrega_estimada: 3.days.from_now.to_date } },
           headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'con seña, registra un movimiento contable de ingreso' do
      expect {
        post "/pacientes/#{paciente.id}/reservas",
             params: { reserva: { stock_id: stock.id, cantidad: 10, sena_ars: 300,
                                  aporte_estimado_ars: 1000, fecha_entrega_estimada: 3.days.from_now.to_date } },
             headers: auth_headers
      }.to change(MovimientoContable, :count).by(1)

      expect(response).to have_http_status(:created)
      mov = MovimientoContable.last
      expect(mov.tipo).to eq('ingreso')
      expect(mov.monto_ars).to eq(300)
    end

  end

  describe 'autorización' do
    it 'el cultivador no puede reservar' do
      sign_in_as(cultivador)
      post "/pacientes/#{paciente.id}/reservas",
           params: { reserva: { stock_id: stock.id, cantidad: 10, fecha_entrega_estimada: 3.days.from_now.to_date } },
           headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /reservas/:id/entregar' do
    before { sign_in_as(dispensador) }

    def crear_reserva(attrs = {})
      Reserva.create!({
        club: club, paciente: paciente, user: dispensador, stock: stock,
        cantidad: 20, fecha_entrega_estimada: Date.current,
        aporte_estimado_ars: 2000,
      }.merge(attrs))
    end

    it 'crea una dispensación, descuenta el stock real y deja la reserva entregada' do
      reserva = crear_reserva
      expect {
        patch "/reservas/#{reserva.id}/entregar", params: { cobros: [{ medio: 'efectivo', monto: 2000 }] }, headers: auth_headers
      }.to change(Dispensacion, :count).by(1)

      expect(response).to have_http_status(:ok)
      reserva.reload
      expect(reserva.estado).to eq('entregada')
      expect(reserva.dispensacion_id).to be_present
      expect(stock.reload.cantidad.to_f).to eq(80.0)        # 100 - 20 descontado real
      expect(stock.reload.gramos_reservados).to eq(0.0)     # ya no bloquea
    end

    it 'con seña previa, cobra sólo el resto (total - seña) en la dispensación' do
      reserva = crear_reserva(sena_ars: 500, aporte_estimado_ars: 2000)
      patch "/reservas/#{reserva.id}/entregar", params: { cobros: [{ medio: 'efectivo', monto: 1500 }] }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      disp = reserva.reload.dispensacion
      expect(disp.aporte_socio_ars).to eq(1500) # 2000 - 500
      expect(disp.cobros.sum(:monto_ars)).to eq(1500)
    end

    it 'no permite entregar dos veces' do
      reserva = crear_reserva
      patch "/reservas/#{reserva.id}/entregar", params: { cobros: [{ medio: 'efectivo', monto: 2000 }] }, headers: auth_headers
      patch "/reservas/#{reserva.id}/entregar", params: { cobros: [{ medio: 'efectivo', monto: 2000 }] }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /reservas/:id/cancelar' do
    before { sign_in_as(dispensador) }

    it 'cancela y libera el stock' do
      reserva = Reserva.create!(club: club, paciente: paciente, user: dispensador, stock: stock,
                                cantidad: 25, fecha_entrega_estimada: 3.days.from_now.to_date)
      expect(stock.reload.gramos_reservados).to eq(25.0)

      patch "/reservas/#{reserva.id}/cancelar", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(reserva.reload.estado).to eq('cancelada')
      expect(stock.reload.gramos_reservados).to eq(0.0)
    end
  end

  describe 'PATCH /reservas/:id (editar)' do
    before { sign_in_as(dispensador) }
    let(:reserva) { Reserva.create!(club: club, paciente: paciente, user: dispensador, stock: stock, cantidad: 20, fecha_entrega_estimada: 3.days.from_now.to_date, aporte_estimado_ars: 2000) }

    it 'edita cantidad y fecha de una reserva pendiente' do
      patch "/reservas/#{reserva.id}", params: { reserva: { cantidad: 15 } }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(reserva.reload.cantidad.to_f).to eq(15.0)
    end

    it 'rechaza cantidad mayor al disponible' do
      patch "/reservas/#{reserva.id}", params: { reserva: { cantidad: 999 } }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'no edita una reserva entregada' do
      reserva.update!(estado: 'entregada')
      patch "/reservas/#{reserva.id}", params: { reserva: { cantidad: 5 } }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /reservas/:id (eliminar)' do
    before { sign_in_as(dispensador) }

    it 'elimina una reserva pendiente sin seña y libera el stock' do
      reserva = Reserva.create!(club: club, paciente: paciente, user: dispensador, stock: stock, cantidad: 10, fecha_entrega_estimada: 3.days.from_now.to_date)
      expect(stock.reload.gramos_reservados).to eq(10.0)
      delete "/reservas/#{reserva.id}", headers: auth_headers
      expect(response).to have_http_status(:no_content)
      expect(Reserva.exists?(reserva.id)).to be(false)
      expect(stock.reload.gramos_reservados).to eq(0.0)
    end

    it 'NO elimina si tiene seña (debe cancelarse)' do
      reserva = Reserva.create!(club: club, paciente: paciente, user: dispensador, stock: stock, cantidad: 10, fecha_entrega_estimada: 3.days.from_now.to_date, sena_ars: 300, aporte_estimado_ars: 1000)
      delete "/reservas/#{reserva.id}", headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(Reserva.exists?(reserva.id)).to be(true)
    end
  end

  describe 'entrega con envío y crédito' do
    before { sign_in_as(dispensador) }
    let(:delivery)  { create(:user, club: club, role: 'delivery') }
    let(:paciente2) { create(:paciente, club: club, created_by: admin, domicilio_calle: 'Corrientes', domicilio_altura: '1234', domicilio_ciudad: 'CABA') }
    let(:reserva)   { Reserva.create!(club: club, paciente: paciente2, user: dispensador, stock: stock, cantidad: 10, fecha_entrega_estimada: Date.current, aporte_estimado_ars: 1000) }

    it 'asigna delivery y toma el domicilio del paciente al entregar (contra-entrega)' do
      patch "/reservas/#{reserva.id}/entregar",
            params: { con_envio: true, delivery_id: delivery.id, usar_domicilio_paciente: true, cobrar_en_entrega: true },
            headers: auth_headers
      expect(response).to have_http_status(:ok)
      disp = reserva.reload.dispensacion
      expect(disp.con_envio).to be(true)
      expect(disp.delivery_id).to eq(delivery.id)
      expect(disp.envio_calle).to eq('Corrientes')
      expect(disp.cobrar_en_entrega).to be(true)
    end

    it 'paga parte en efectivo y el resto queda en cuenta corriente' do
      cc = CuentaCorriente.create!(paciente: paciente2, club: club, saldo_disponible: 0, limite_credito: 600)
      patch "/reservas/#{reserva.id}/entregar", params: { cobros: [{ medio: 'efectivo', monto: 400 }] }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      disp = reserva.reload.dispensacion
      expect(disp.aporte_socio_ars.to_f).to eq(1000.0)
      expect(disp.monto_credito_ars.to_f).to eq(600.0)   # 400 efectivo + 600 a cuenta
      expect(cc.reload.saldo_disponible.to_f).to eq(-600.0)
    end
  end

  describe 'aislamiento por tenant' do
    let(:otro_club)        { create(:club) }
    let(:otro_admin)       { create(:user, :admin, club: otro_club) }
    let(:otra_sede)        { create(:sede, club: otro_club, created_by: otro_admin) }
    let(:otra_sala)        { create(:sala, club: otro_club, sede: otra_sede, created_by: otro_admin) }
    let(:otro_lote)        { create(:lote, club: otro_club, sala: otra_sala) }
    let(:otro_paciente)    { create(:paciente, club: otro_club, created_by: otro_admin) }
    let!(:otro_stock)      { Stock.create!(sede: otra_sede, lote: otro_lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 50) }
    let!(:reserva_ajena)   { Reserva.create!(club: otro_club, paciente: otro_paciente, user: otro_admin, stock: otro_stock, cantidad: 10, fecha_entrega_estimada: 3.days.from_now.to_date) }

    before { sign_in_as(dispensador) }

    it 'no lista reservas de otro club' do
      get '/reservas', headers: auth_headers
      ids = JSON.parse(response.body)['reservas'].map { |r| r['id'] }
      expect(ids).not_to include(reserva_ajena.id)
    end

    it 'no puede entregar una reserva de otro club (404)' do
      patch "/reservas/#{reserva_ajena.id}/entregar", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
