require 'rails_helper'

# Fase 3 — Pacientes y dispensaciones, desde el mostrador. Igual que en cultivo: no verifica
# el camino feliz, fuerza lo que pasa de verdad un sábado con gente esperando y comprueba que
# la respuesta se entienda y diga QUÉ HACER.
RSpec.describe 'Dispensación — casos reales', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let(:stock)    { create(:stock, club: club, sede: sede, cantidad: 100, precio_sugerido_ars: 1000) }

  def json = JSON.parse(response.body)
  def error_msg = json['error'] || Array(json['errors']).join(', ')

  def dispensar(params)
    post "/api/pacientes/#{paciente.id}/dispensaciones", params: { dispensacion: params }, as: :json
  end

  describe 'el stock que no alcanza' do
    before { sign_in_as(dispensador) }

    # Lo más común del mostrador: se pide más de lo que hay.
    it 'no deja dispensar más de lo disponible, y dice cuánto hay' do
      dispensar(stock_id: stock.id, cantidad: 500, fecha_dispensacion: Time.zone.today)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/disponible|suficiente|stock/i)
    end

    it 'una cantidad en cero o negativa se rechaza' do
      dispensar(stock_id: stock.id, cantidad: 0, fecha_dispensacion: Time.zone.today)
      expect(response).to have_http_status(:unprocessable_entity)

      dispensar(stock_id: stock.id, cantidad: -5, fecha_dispensacion: Time.zone.today)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'no se puede dispensar con fecha futura' do
      dispensar(stock_id: stock.id, cantidad: 5, fecha_dispensacion: 3.days.from_now.to_date)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/futura/i)
    end
  end

  describe 'el paciente que no corresponde' do
    before { sign_in_as(dispensador) }

    it 'a uno dado de baja no se le dispensa, y se explica' do
      paciente.update!(es_paciente: false)

      dispensar(stock_id: stock.id, cantidad: 5, fecha_dispensacion: Time.zone.today)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/no está activo/i)
    end

    it 'un paciente de otro club no existe para este' do
      otro = create(:club)
      otro_admin = create(:user, :admin, club: otro)
      ajeno = ActsAsTenant.with_tenant(otro) { create(:paciente, club: otro, created_by: otro_admin) }

      post "/api/pacientes/#{ajeno.id}/dispensaciones",
           params: { dispensacion: { stock_id: stock.id, cantidad: 5, fecha_dispensacion: Time.zone.today } },
           as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'el stock de otro club' do
    before { sign_in_as(dispensador) }

    # El agujero clásico de multi-tenancy: mandar el id de un stock ajeno en el payload.
    it 'no se puede dispensar stock que no es del club' do
      otro = create(:club)
      otro_admin = create(:user, :admin, club: otro)
      sede_ajena = ActsAsTenant.with_tenant(otro) { create(:sede, club: otro, created_by: otro_admin, tipo: 'mixta') }
      ajeno = ActsAsTenant.with_tenant(otro) { create(:stock, club: otro, sede: sede_ajena, cantidad: 500) }

      dispensar(stock_id: ajeno.id, cantidad: 5, fecha_dispensacion: Time.zone.today)

      expect(response).not_to have_http_status(:created)
      expect(ajeno.reload.cantidad.to_f).to eq(500.0)
    end
  end

  describe 'la cuenta corriente' do
    before { sign_in_as(dispensador) }

    # El crédito NO es un tope duro, a propósito: cubre hasta donde llega y la diferencia se
    # cobra en el momento. Lo que sí tiene que pasar es que al crédito no le caiga MÁS de lo
    # que el paciente tiene disponible, o el club regalaría mercadería sin darse cuenta.
    it 'al crédito le cae como mucho lo que el paciente tiene disponible' do
      paciente.create_cuenta_corriente!(club: club, limite_credito: 5_000, saldo_disponible: 0)

      dispensar(stock_id: stock.id, cantidad: 50, fecha_dispensacion: Time.zone.today,
                medio_pago: 'cuenta_corriente', aporte_socio_ars: 50_000)

      expect(response).to have_http_status(:created), error_msg
      d = Dispensacion.last
      # $50.000 de dispensa contra $5.000 de crédito: sólo 5.000 van a cuenta corriente y el
      # resto se cobra ahora.
      expect(d.monto_credito_ars.to_f).to eq(5_000.0)
    end

    it 'sin crédito configurado, no se puede cobrar por cuenta corriente' do
      dispensar(stock_id: stock.id, cantidad: 5, fecha_dispensacion: Time.zone.today,
                medio_pago: 'cuenta_corriente', aporte_socio_ars: 5_000)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/no tiene cr[ée]dito configurado/i)
    end

    # "No abona" sí es un tope duro: es el club regalando, y no puede pasarse del límite.
    it '"no abona" se frena cuando no alcanza el crédito' do
      paciente.create_cuenta_corriente!(club: club, limite_credito: 1_000, saldo_disponible: 0)

      dispensar(stock_id: stock.id, cantidad: 50, fecha_dispensacion: Time.zone.today,
                medio_pago: 'no_abona', aporte_socio_ars: 50_000)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_msg).to match(/insuficiente/i)
    end
  end

  describe 'quién puede hacer qué' do
    it 'el cultivador no dispensa' do
      sign_in_as(create(:user, :cultivador, club: club))

      dispensar(stock_id: stock.id, cantidad: 5, fecha_dispensacion: Time.zone.today)

      expect(response).to have_http_status(:forbidden)
    end

    it 'el supervisor sí dispensa' do
      sign_in_as(create(:user, :supervisor, club: club))

      dispensar(stock_id: stock.id, cantidad: 5, fecha_dispensacion: Time.zone.today)

      expect(response).to have_http_status(:created), error_msg
    end

    # El REPROCANN no es asunto del dispensador: su regla es "si está en la lista, dispensa".
    it 'el dispensador no ve el REPROCANN del paciente' do
      sign_in_as(dispensador)

      get "/api/pacientes/#{paciente.id}"

      expect(response).to have_http_status(:ok)
      expect(json['data']).not_to have_key('reprocann_numero')
    end

    it 'ni su historia clínica' do
      sign_in_as(dispensador)

      get "/api/pacientes/#{paciente.id}"

      expect(json['data']).not_to have_key('notas_clinicas')
      expect(json['data']).not_to have_key('diagnostico_principal')
    end
  end

  describe 'el stock después de dispensar' do
    before { sign_in_as(dispensador) }

    it 'se descuenta exactamente lo entregado' do
      dispensar(stock_id: stock.id, cantidad: 15, fecha_dispensacion: Time.zone.today)

      expect(response).to have_http_status(:created), error_msg
      expect(stock.reload.cantidad.to_f).to eq(85.0)
    end

    # Si la dispensación falla a mitad de camino, el stock no puede quedar descontado.
    it 'un rechazo no toca el stock' do
      dispensar(stock_id: stock.id, cantidad: 999, fecha_dispensacion: Time.zone.today)

      expect(stock.reload.cantidad.to_f).to eq(100.0)
    end
  end

  describe 'las reservas' do
    before { sign_in_as(dispensador) }

    # El dispensador ENTREGA reservas pero no las crea: crearlas es comprometer stock a
    # futuro, que es decisión de quien gestiona.
    it 'el dispensador no crea reservas' do
      post "/api/pacientes/#{paciente.id}/reservas",
           params: { reserva: { stock_id: stock.id, cantidad: 10,
                                fecha_entrega_estimada: 2.days.from_now.to_date } }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'una reserva para hoy o para ayer se rechaza: reservar es a futuro' do
      sign_in_as(admin)

      post "/api/pacientes/#{paciente.id}/reservas",
           params: { reserva: { stock_id: stock.id, cantidad: 10,
                                fecha_entrega_estimada: Time.zone.today } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
