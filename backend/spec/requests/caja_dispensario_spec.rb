require 'rails_helper'

# LA CAJA DEL MOSTRADOR DE DISPENSA.
#
# La mecánica ya existía para el buffet; lo único que la ataba ahí era `bar_id NOT NULL`.
# `CajaTurno` apunta a un PUNTO DE VENTA —una `Barra` o un `Mostrador`— y las dos la usan.
#
# Son cajas INDEPENDIENTES: el buffet y el mostrador abren, arquean y cierran por separado, y la
# plata nunca se mezcla. Lo que se comparte es el código.
#
# DÓNDE SE ABRE Y SE CIERRA: en el MOSTRADOR, no acá. `POST /sedes/:id/caja/abrir` existió y sólo
# pedía un fondo — abrir por ahí salteaba la mitad del arqueo, porque no contaba la mercadería.
# Ahora es un solo gesto: quien atiende cuenta lo que hay sobre la mesa, cuenta la plata, y
# arranca. Lo que quedó en `cajas#*` es lo que es de la caja y no del mostrador: mover plata y
# anular una que se abrió por error.
RSpec.describe 'Caja del mostrador de dispensa', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }

  # Abrir es contar: la mercadería que hay arriba y la plata que hay en el cajón.
  def abrir!(fondo: 10_000, como: ana, conteos: [])
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/abrir", headers: auth_headers,
         params: { efectivo_contado_ars: fondo, conteos: conteos }
    JSON.parse(response.body)
  end

  def actual(como)
    sign_in_as(como)
    get "/api/sedes/#{sede.id}/caja/actual", headers: auth_headers
    JSON.parse(response.body)['caja']
  end

  describe 'el arranque' do
    it 'quien atiende la abre contando lo que hay, y queda abierta' do
      turno = abrir!(fondo: 10_000)

      expect(response).to have_http_status(:created)
      expect(turno['estado']).to eq('abierto')
      expect(turno['abierto_por']).to eq(ana.nombre_completo)
      expect(turno['caja']['fondo_ars']).to eq(10_000.0)
      expect(actual(admin)['estado']).to eq('abierta')
    end

    # Al revés de como era: la caja la abría el admin declarando el fondo y quien atiende lo
    # confirmaba después. Eran dos pasos para la misma verificación, y el segundo era un botón
    # que nadie miraba. Ahora abre quien atiende, contando — que es el único momento en que
    # alguien de verdad mira lo que hay.
    it 'la abre el dispensador: es quien atiende, y contar es su trabajo' do
      abrir!(como: ana)

      expect(response).to have_http_status(:created)
      expect(TurnoMostrador.where(club_id: club.id).abiertos.count).to eq(1)
    end

    # Administración también puede: en una organización de una sola persona no hay a quién
    # esperar, y un mostrador que no abre es una sede que no dispensa.
    it 'también la abre administración' do
      abrir!(como: admin)

      expect(response).to have_http_status(:created)
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
      turno = ActsAsTenant.with_tenant(club) do
        lote  = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
        stock = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                               cantidad: 500, precio_sugerido_ars: 100)
        pac = create(:paciente, club: club)
        pac.create_cuenta_corriente!(club: club, saldo_disponible: 0, limite_credito: 50_000)
        # El dispensador entrega de lo que está sobre la mesa, así que primero hay mostrador: la
        # mesa la carga administración y ana abre contándola.
        t = abrir_mostrador!(sede, usuario: admin, recibe: ana, fondo: 10_000)

        disp = Dispensacion.create!(paciente: pac, user: ana, stock: stock, sede: sede, cantidad: 5,
                                    medio_pago: 'efectivo', aporte_socio_ars: 9_000,
                                    fecha_dispensacion: Time.zone.today)

        Dispensaciones::RegistrarCobro.call(dispensacion: disp, club: club, usuario: ana,
                                            medio: 'efectivo', monto: 4_000)
        Dispensaciones::RegistrarCobro.call(dispensacion: disp, club: club, usuario: ana,
                                            medio: 'transferencia', monto: 3_000)
        Dispensaciones::RegistrarCobro.call(dispensacion: disp, club: club, usuario: ana,
                                            medio: 'cuenta_corriente', monto: 2_000)
        t
      end

      caja = actual(admin)

      expect(caja['total_efectivo_ars']).to eq(4_000.0)
      expect(caja['total_digital_ars']).to eq(3_000.0)      # la transferencia
      expect(caja['efectivo_esperado_ars']).to eq(14_000.0) # 10.000 de fondo + 4.000 en efectivo
      expect(caja['id']).to eq(turno.caja_turno_id)
    end

    # CIERRA EN EL ACTO, sin esperar al admin. Antes eran dos pasos —el operador enviaba el conteo
    # y el admin lo confirmaba— y eso dejaba el mostrador bloqueado a las once de la noche: el que
    # abría a la mañana no podía arrancar. El aval del admin es asincrónico y vive en la solapa de
    # Merma.
    it 'el dispensador cuenta y cierra, sin esperar a nadie' do
      abrir!(fondo: 10_000)

      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/mostrador/cerrar", headers: auth_headers,
           params: { efectivo_contado_ars: 9_500, notas: 'faltan 500' }

      expect(response).to have_http_status(:ok)
      cuerpo = JSON.parse(response.body)
      expect(cuerpo['estado']).to eq('cerrado')
      expect(cuerpo['cerrado_por']).to eq(ana.nombre_completo)
      expect(cuerpo['caja']['diferencia_ars']).to eq(-500.0)
      expect(actual(admin)).to be_nil
    end

    # La diferencia se ANOTA, no bloquea: la merma es inevitable y no es culpa de nadie. Un cierre
    # que no cierra deja el mostrador trabado y a alguien explicando gramos a las once de la noche.
    it 'una diferencia no impide cerrar' do
      abrir!(fondo: 10_000)

      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/mostrador/cerrar", headers: auth_headers,
           params: { efectivo_contado_ars: 3_000, notas: 'me faltó plata' }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['estado']).to eq('cerrado')
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
