require 'rails_helper'

# AC (Germán): "un arranque de caja, el admin abre la caja, el dispensador confirma, y se arranca".
#
# La mecánica ya existía para el buffet y estaba probada; lo único que la ataba ahí era
# `bar_id NOT NULL`. `CajaTurno` pasa a apuntar a un PUNTO DE VENTA —una `Barra` o una `Sede`— y
# el mostrador de dispensa usa el mismo flujo.
#
# Son cajas INDEPENDIENTES: el buffet y el mostrador abren, arquean y cierran por separado, y la
# plata nunca se mezcla. Lo que se comparte es el código.
RSpec.describe 'Caja del mostrador de dispensa', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }

  def abrir!(monto: 10_000, como: admin)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/caja/abrir", headers: auth_headers, params: { monto_inicial_ars: monto }
    JSON.parse(response.body)
  end

  def actual(como)
    sign_in_as(como)
    get "/api/sedes/#{sede.id}/caja/actual", headers: auth_headers
    JSON.parse(response.body)['caja']
  end

  describe 'el arranque' do
    it 'el admin la abre con un fondo y queda sin confirmar' do
      caja = abrir!(monto: 10_000)

      expect(response).to have_http_status(:created)
      expect(caja['estado']).to eq('abierta')
      expect(caja['monto_inicial_ars']).to eq(10_000.0)
      expect(caja['apertura_confirmada']).to be(false)
    end

    it 'el dispensador confirma que el fondo está' do
      caja = abrir!
      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/caja/#{caja['id']}/confirmar_apertura", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['apertura_confirmada']).to be(true)
      expect(JSON.parse(response.body)['apertura_confirmada_por']).to eq(ana.nombre_completo)
    end

    # Los dos pasos existen para que ninguno quede solo respondiendo por una diferencia de arqueo.
    it 'el dispensador NO puede abrirla: quien declara el fondo es quien responde por él' do
      abrir!(como: ana)

      expect(response).to have_http_status(:forbidden)
    end

    it 'no deja abrir dos cajas en el mismo mostrador' do
      abrir!
      abrir!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/ya hay una caja/i)
    end
  end

  describe 'el arqueo' do
    # Lo cobrado sale de los `cobros` enganchados a la caja. La cuenta corriente NO entra: es una
    # deuda que se registra, no plata que entró al cajón, y sumarla daría faltante siempre.
    it 'espera el fondo más lo cobrado en efectivo, sin contar lo que quedó a cuenta' do
      caja_json = abrir!(monto: 10_000)

      ActsAsTenant.with_tenant(club) do
        lote  = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
        stock = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                               cantidad: 500, precio_sugerido_ars: 100)
        pac = create(:paciente, club: club)
        pac.create_cuenta_corriente!(club: club, saldo_disponible: 0, limite_credito: 50_000)
        disp = Dispensacion.create!(paciente: pac, user: ana, stock: stock, sede: sede, cantidad: 5,
                                    medio_pago: 'efectivo', aporte_socio_ars: 9_000,
                                    fecha_dispensacion: Time.zone.today)

        Dispensaciones::RegistrarCobro.call(dispensacion: disp, club: club, usuario: ana,
                                            medio: 'efectivo', monto: 4_000)
        Dispensaciones::RegistrarCobro.call(dispensacion: disp, club: club, usuario: ana,
                                            medio: 'transferencia', monto: 3_000)
        Dispensaciones::RegistrarCobro.call(dispensacion: disp, club: club, usuario: ana,
                                            medio: 'cuenta_corriente', monto: 2_000)
      end

      caja = actual(admin)

      expect(caja['total_efectivo_ars']).to eq(4_000.0)
      expect(caja['total_digital_ars']).to eq(3_000.0)      # la transferencia
      expect(caja['efectivo_esperado_ars']).to eq(14_000.0) # 10.000 de fondo + 4.000 en efectivo
      expect(caja['id']).to eq(caja_json['id'])
    end

    it 'el dispensador cuenta y envía; el admin confirma' do
      caja = abrir!(monto: 10_000)

      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/caja/#{caja['id']}/solicitar_cierre",
           headers: auth_headers, params: { efectivo_declarado_ars: 9_500, notas: 'faltan 500' }
      enviada = JSON.parse(response.body)

      expect(enviada['estado']).to eq('pendiente_cierre')
      expect(enviada['diferencia_ars']).to eq(-500.0)
      expect(enviada['cierre_solicitado_por']).to eq(ana.nombre_completo)

      sign_in_as(admin)
      post "/api/sedes/#{sede.id}/caja/#{caja['id']}/confirmar_cierre", headers: auth_headers

      expect(JSON.parse(response.body)['estado']).to eq('cerrada')
    end

    it 'el dispensador NO puede confirmar su propio cierre' do
      caja = abrir!
      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/caja/#{caja['id']}/confirmar_cierre", headers: auth_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  # Lo que motivó generalizar en vez de duplicar: un solo código, dos cajas que no se tocan.
  describe 'convive con la del buffet' do
    it 'abrir la del mostrador no ocupa la del bar de la misma sede' do
      bar = ActsAsTenant.with_tenant(club) { create(:barra, club: club, sede: sede) }
      abrir!

      sign_in_as(admin)
      post "/api/bares/#{bar.id}/cajas/abrir", headers: auth_headers, params: { monto_inicial_ars: 5_000 }

      expect(response).to have_http_status(:created)
      expect(CajaTurno.where(club_id: club.id).activas.count).to eq(2)
    end

    it 'lo cobrado en el mostrador no entra en la caja del bar' do
      bar = ActsAsTenant.with_tenant(club) { create(:barra, club: club, sede: sede) }
      abrir!
      sign_in_as(admin)
      post "/api/bares/#{bar.id}/cajas/abrir", headers: auth_headers, params: { monto_inicial_ars: 5_000 }
      caja_bar = JSON.parse(response.body)

      expect(caja_bar['total_efectivo_ars']).to eq(0.0)
      expect(caja_bar['monto_inicial_ars']).to eq(5_000.0)
    end
  end
end
