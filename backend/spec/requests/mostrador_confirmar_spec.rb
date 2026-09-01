require 'rails_helper'

# La ENTREGA del mostrador: el admin lo carga y el que atiende confirma que lo recibió.
#
# No es el relevo que se descartó —ahí la misma persona contaba dos veces lo que ella misma había
# dejado, y termina en un botón que nadie mira—. Acá son DOS personas: el admin declara "puse
# 300 g sobre la mesa" y el que atiende dice "sí, están".
#
# Sirve para que el arqueo del cierre mida la merma de verdad. Sin confirmar el punto de partida,
# la diferencia de la noche mezcla lo que se consumió atendiendo con lo que nunca estuvo.
RSpec.describe 'Recibir el mostrador', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:ana)      { create(:user, :dispensador, club: club) }
  let(:sede)     { create(:sede, club: club, tipo: 'social') }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  def abrir!(cantidad: 300, como: admin)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/abrir", headers: auth_headers,
         params: { monto_inicial_ars: 10_000, items: [{ stock_id: stock.id, cantidad: cantidad }] }
    JSON.parse(response.body)
  end

  def item = sede.mostrador!.turno_abierto.items.first

  def confirmar!(correcciones: [], como: ana)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/confirmar", headers: auth_headers,
         params: { correcciones: correcciones }
    JSON.parse(response.body)
  end

  def dispensar!(cantidad, como: ana)
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: como, stock: stock, sede: sede,
                           cantidad: cantidad, medio_pago: 'efectivo',
                           aporte_socio_ars: cantidad * 100, fecha_dispensacion: Time.zone.today)
    end
  end

  describe 'cuando lo carga el admin' do
    before { abrir! }

    it 'queda esperando que lo reciba quien atiende' do
      expect(sede.mostrador!.turno_abierto).not_to be_confirmado
    end

    # La firma tiene que valer algo: si se pudiera atender sin recibir, al cierre el que atendió
    # responde por lo que otro declaró y nadie miró.
    it 'sin confirmar no se dispensa' do
      expect { dispensar!(10) }
        .to raise_error(ActiveRecord::RecordInvalid, /Confirmá lo que hay en el mostrador/i)
    end

    it 'y el carrito tampoco le ofrece nada' do
      sign_in_as(ana)
      get '/api/stocks', headers: auth_headers, params: { para_dispensa: true }

      expect(JSON.parse(response.body)).to eq([])
    end

    it 'confirmado, queda con nombre y hora, y ya se puede atender' do
      body = confirmar!

      expect(response).to have_http_status(:ok)
      expect(body['confirmado']).to be(true)
      expect(body['confirmado_por']).to eq(ana.nombre_completo)
      expect { dispensar!(10) }.not_to raise_error
    end

    # Dos firmas de la misma persona no son ninguna: si el que carga la mesa se la puede recibir,
    # el paso es decorativo.
    it 'el que cargó la mesa no se la recibe a sí mismo' do
      body = confirmar!(como: admin)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/quien vaya a atender/i)
      expect(sede.mostrador!.turno_abierto).not_to be_confirmado
    end

    it 'no se confirma dos veces' do
      confirmar!
      body = confirmar!

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/ya fue confirmado/i)
    end
  end

  describe 'cuando lo que hay no coincide con lo que declaró el admin' do
    before { abrir!(cantidad: 300) }

    it 'lo corrige, y la corrección queda con su nombre' do
      body = confirmar!(correcciones: [{ item_id: item.id, contado: 297, motivo: 'faltaban 3 g' }])

      expect(response).to have_http_status(:ok)
      expect(body['items'].first['esperado']).to eq(297.0)
      expect(body['items'].first['correccion']).to eq(-3.0)
      mov = TurnoMostradorMovimiento.unscoped.correcciones.last
      expect(mov.usuario_id).to eq(ana.id)
      expect(mov.notas).to eq('faltaban 3 g')
    end

    # Los 3 g que el admin declaró de más NO se perdieron: siguen en el depósito. Corregir el
    # reparto entre mesa y depósito no toca el inventario.
    it 'corregir no toca el inventario: la mercadería nunca salió' do
      expect {
        confirmar!(correcciones: [{ item_id: item.id, contado: 297, motivo: 'faltaban 3 g' }])
      }.not_to change { StockMovimiento.where(stock_id: stock.id).count }

      expect(stock.reload.cantidad.to_f).to eq(500.0)
      expect(stock.cantidad_disponible_real.to_f).to eq(203.0) # los 3 vuelven al depósito
    end

    it 'también se corrige en más, si el admin puso menos de lo que dejó' do
      confirmar!(correcciones: [{ item_id: item.id, contado: 320, motivo: 'había 20 más' }])

      expect(sede.mostrador!.turno_abierto.items.first.esperado.to_f).to eq(320.0)
    end

    it 'pero no se puede inventar lo que no hay en el depósito' do
      body = confirmar!(correcciones: [{ item_id: item.id, contado: 900, motivo: 'me parece' }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/quedan 200/i)
    end

    it 'una diferencia sin motivo no se acepta' do
      body = confirmar!(correcciones: [{ item_id: item.id, contado: 297 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/escribí el motivo/i)
    end

    # Lo corregido es lo que después se arquea: el cierre compara contra lo que ÉL recibió, no
    # contra lo que el admin declaró.
    it 'el cierre se mide contra lo que recibió, no contra lo que declaró el admin' do
      confirmar!(correcciones: [{ item_id: item.id, contado: 297, motivo: 'faltaban 3 g' }])
      dispensar!(50)

      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/mostrador/cerrar", headers: auth_headers,
           params: { conteos: [{ item_id: item.id, contado: 247 }], efectivo_contado_ars: 15_000 }

      expect(response).to have_http_status(:ok) # 297 − 50 = 247, cuadra
    end
  end

  # Se recibe la mesa Y la plata: son los dos arqueos, y los dos tienen que arrancar de un número
  # verificado o el cierre no mide nada.
  describe 'la plata también se recibe' do
    before { abrir!(cantidad: 300) } # fondo declarado: $10.000

    def caja = sede.mostrador!.caja_abierta

    it 'si coincide, confirma sin asentar nada' do
      expect {
        confirmar!(correcciones: [], como: ana)
      }.not_to change { MovimientoContable.unscoped.where(categoria: 'diferencia_caja').count }
      expect(response).to have_http_status(:ok)
    end

    it 'si hay menos, el fondo pasa a ser lo contado y la diferencia queda asentada' do
      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/mostrador/confirmar", headers: auth_headers,
           params: { efectivo_contado_ars: 8_000, motivo_efectivo: 'faltaban $2.000' }

      expect(response).to have_http_status(:ok)
      expect(caja.reload.monto_inicial_ars.to_f).to eq(8_000.0)
      mov = MovimientoContable.unscoped.where(categoria: 'diferencia_caja').last
      expect(mov.monto_ars.to_f).to eq(2_000.0)
      expect(mov.tipo).to eq('egreso')       # a diferencia del stock, la plata que falta se perdió
      expect(mov.created_by_id).to eq(ana.id) # quién la detectó
      expect(mov.descripcion).to match(/al recibir el mostrador/i)
    end

    # Si el fondo no se corrigiera, el cierre volvería a encontrar la misma diferencia.
    it 'y el cierre ya no la vuelve a contar' do
      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/mostrador/confirmar", headers: auth_headers,
           params: { efectivo_contado_ars: 8_000, motivo_efectivo: 'faltaban $2.000' }

      expect(caja.reload.efectivo_esperado_ars).to eq(8_000.0)
    end

    it 'un sobrante también se asienta' do
      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/mostrador/confirmar", headers: auth_headers,
           params: { efectivo_contado_ars: 12_000, motivo_efectivo: 'había $2.000 de más' }

      expect(MovimientoContable.unscoped.where(categoria: 'diferencia_caja').last.tipo).to eq('ingreso')
      expect(caja.reload.monto_inicial_ars.to_f).to eq(12_000.0)
    end

    it 'con diferencia y sin motivo no confirma' do
      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/mostrador/confirmar", headers: auth_headers,
           params: { efectivo_contado_ars: 8_000 }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/escribí el motivo/i)
      expect(sede.mostrador!.turno_abierto).not_to be_confirmado
    end
  end

  # El admin puede corregir la plata en cualquier momento, en los dos sentidos.
  describe 'el admin mueve plata durante el turno' do
    before { abrir!(cantidad: 300) }

    def caja = sede.mostrador!.caja_abierta

    it 'pone plata en el cajón y el arqueo la espera' do
      sign_in_as(admin)
      post "/api/sedes/#{sede.id}/caja/#{caja.id}/ingreso", headers: auth_headers,
           params: { monto_ars: 5_000, motivo: 'traje cambio' }

      expect(response).to have_http_status(:ok)
      expect(caja.reload.efectivo_esperado_ars).to eq(15_000.0)
      expect(caja.total_ingresos_ars).to eq(5_000.0)
    end

    it 'y sacarla la descuenta, como siempre' do
      sign_in_as(admin)
      post "/api/sedes/#{sede.id}/caja/#{caja.id}/salida", headers: auth_headers,
           params: { monto_ars: 3_000, motivo: 'flete', clase: 'gasto' }

      expect(caja.reload.efectivo_esperado_ars).to eq(7_000.0)
    end

    # No es un ingreso del club: esa plata ya era suya, sólo cambió de lugar.
    it 'poner plata en el cajón no infla el resultado' do
      sign_in_as(admin)
      expect {
        post "/api/sedes/#{sede.id}/caja/#{caja.id}/ingreso", headers: auth_headers,
             params: { monto_ars: 5_000, motivo: 'traje cambio' }
      }.not_to change { MovimientoContable.unscoped.where(club_id: club.id).ingresos.sum(:monto_ars) }
    end

    it 'el dispensador no mueve plata: responde quien administra' do
      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/caja/#{caja.id}/ingreso", headers: auth_headers,
           params: { monto_ars: 5_000, motivo: 'traje cambio' }

      expect(response).to have_http_status(:forbidden)
    end
  end

  # Si lo abre el que va a atender, cargó la mesa él mismo: no hay entrega que firmar. Puede
  # abrirla —el mostrador no tiene que depender de que haya un admin a las 8 de la mañana— pero
  # sólo con lo que HEREDÓ del cierre anterior: traer algo del depósito es sacar mercadería, y eso
  # lo hace quien responde por ella.
  describe 'cuando lo abre el propio dispensador' do
    before do
      # Un turno anterior cerrado con 250: es lo que va a poder heredar.
      abrir!(cantidad: 300)
      turno = sede.mostrador!.turno_abierto
      ActsAsTenant.with_tenant(club) do
        Mostradores::ConfirmarApertura.call(turno: turno, usuario: ana)
        Mostradores::CerrarTurno.call(turno: turno, usuario: ana, efectivo_contado_ars: 10_000,
                                      conteos: [{ item_id: turno.items.first.id, contado: 250,
                                                  motivo: 'conteo' }])
      end
    end

    it 'queda confirmado en el acto' do
      abrir!(cantidad: 250, como: ana)

      expect(response).to have_http_status(:created)
      expect(sede.mostrador!.turno_abierto).to be_confirmado
      expect { dispensar!(10) }.not_to raise_error
    end

    it 'pero no puede traer del depósito lo que no venía' do
      body = abrir!(cantidad: 300, como: ana) # heredó 250

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/se puede corregir para abajo, no para arriba/i)
    end
  end
end
