require 'rails_helper'

# Cerrar el mostrador: los dos arqueos en un solo gesto, y sin esperar al admin.
#
# Son arqueos INDEPENDIENTES y sólo el efectivo los cruza. El de mercadería no mira el medio de
# pago: lo que salió de la mesa salió, se haya cobrado o no. El de plata sólo cuenta lo que entró
# al cajón — la cuenta corriente es deuda, y lo que cobró el repartidor está en su bolsillo.
RSpec.describe 'Cerrar el mostrador', type: :request do
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

  def abrir!(cantidad: 300, fondo: 50_000, como: ana)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/abrir", headers: auth_headers,
         params: { monto_inicial_ars: fondo, items: [{ stock_id: stock.id, cantidad: cantidad }] }
  end

  def dispensar!(cantidad, medio: 'efectivo')
    ActsAsTenant.with_tenant(club) do
      d = Dispensacion.create!(paciente: paciente, user: ana, stock: stock, sede: sede,
                               cantidad: cantidad, medio_pago: medio,
                               aporte_socio_ars: cantidad * 100, fecha_dispensacion: Time.zone.today)
      Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: ana, medio: medio,
                                          monto: cantidad * 100, contexto: 'creacion')
      d
    end
  end

  def item = sede.mostrador.turno_abierto.items.first

  def cerrar!(contado:, motivo: nil, efectivo: nil, fondo: nil, como: ana)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/cerrar", headers: auth_headers,
         params: { conteos: [{ item_id: item.id, contado: contado, motivo: motivo }.compact],
                   efectivo_contado_ars: efectivo, fondo_siguiente_ars: fondo }
    JSON.parse(response.body)
  end

  describe 'el arqueo de mercadería' do
    before { abrir!(cantidad: 300) }

    it 'cuadrado, cierra sin tocar el inventario' do
      dispensar!(85)

      expect { cerrar!(contado: 215, efectivo: 58_500) }
        .not_to change { StockMovimiento.where(stock_id: stock.id, tipo: 'ajuste').count }
      expect(response).to have_http_status(:ok)
      expect(stock.reload.cantidad.to_f).to eq(415.0)
    end

    # El caso más común: 17 pesadas de 5 g y la balanza redondea para arriba.
    it 'un faltante ajusta el stock y deja el motivo escrito' do
      dispensar!(85)

      cerrar!(contado: 211.4, motivo: 'merma de fraccionamiento', efectivo: 58_500)

      expect(stock.reload.cantidad.to_f).to eq(411.4)
      mov = stock.stock_movimientos.where(tipo: 'ajuste').last
      expect(mov.gramos.to_f).to eq(-3.6)
      expect(mov.notas).to match(/faltante de 3\.6 g — merma de fraccionamiento/)
    end

    it 'un sobrante también se asienta' do
      dispensar!(85)

      cerrar!(contado: 216.2, motivo: 'se entregó de menos', efectivo: 58_500)

      expect(stock.reload.cantidad.to_f).to eq(416.2)
      expect(stock.stock_movimientos.where(tipo: 'ajuste').last.gramos.to_f).to eq(1.2)
    end

    # La regla de oro: lo trazable sale del inventario por dispensación. Un faltante de arqueo es
    # una corrección de conteo, no una salida — por eso NUNCA es merma, que es lo que cuenta el
    # informe de Pérdidas.
    it 'el ajuste nunca es merma' do
      dispensar!(85)
      cerrar!(contado: 211.4, motivo: 'merma de fraccionamiento', efectivo: 58_500)

      expect(stock.stock_movimientos.where(tipo: 'merma').count).to eq(0)
    end

    it 'con diferencia y sin motivo, no cierra' do
      body = cerrar!(contado: 250)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/escribí el motivo/i)
      expect(sede.mostrador.turno_abierto).to be_present
    end

    # Contar sólo algunos ítems es un arqueo que no arquea: el que falta se arrastra al turno
    # siguiente como si nada.
    it 'hay que contar todo lo que está sobre la mesa' do
      otro = ActsAsTenant.with_tenant(club) do
        create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'preroll', unidad: 'un',
                       cantidad: 50, estado: 'asignado', disponibilidad: 'ambas')
      end
      sign_in_as(admin)
      post "/api/sedes/#{sede.id}/mostrador/cargar", headers: auth_headers,
           params: { stock_id: otro.id, cantidad: 20 }

      body = cerrar!(contado: 300, efectivo: 50_000)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/falta contar/i)
    end

    it 'al cerrar se libera el apartado y el stock vuelve a estar libre' do
      dispensar!(85)
      cerrar!(contado: 215, efectivo: 58_500)

      expect(stock.reload.apartado_para_mostrador.to_f).to eq(0.0)
      expect(stock.cantidad_disponible_real.to_f).to eq(415.0)
    end
  end

  # El arqueo de mercadería no mira cómo se pagó: el producto salió igual.
  describe 'los dos arqueos son independientes' do
    before { abrir!(cantidad: 300, fondo: 10_000) }

    it 'una dispensa a cuenta corriente baja la mesa pero no la caja' do
      ActsAsTenant.with_tenant(club) do
        paciente.cuenta_corriente&.update!(limite_credito: 100_000)
      end
      dispensar!(50, medio: 'cuenta_corriente')

      turno = sede.mostrador.turno_abierto
      expect(turno.items.first.esperado.to_f).to eq(250.0)
      expect(turno.caja_turno.efectivo_esperado_ars).to eq(10_000.0) # sólo el fondo
    end
  end

  describe 'el fondo y el retiro' do
    before do
      abrir!(cantidad: 300, fondo: 50_000)
      dispensar!(85) # $8.500 en efectivo
    end

    # El agujero que no existía: si contás $58.500 y mañana abrís con $50.000, los otros $8.500
    # no tenían ningún movimiento que dijera que salieron del cajón.
    it 'lo que no queda de fondo sale como retiro, con dueño' do
      cerrar!(contado: 215, efectivo: 58_500, fondo: 50_000, como: admin)

      retiro = MovimientoContable.unscoped.where(club_id: club.id, categoria: 'retiro_caja').last
      expect(retiro.monto_ars.to_f).to eq(8_500.0)
      expect(retiro.tipo).to eq('ajuste') # no es un gasto: la plata sigue siendo del club
      expect(retiro.retirado_por_id).to eq(admin.id)
      expect(retiro.descripcion).to match(/queda \$50000 de fondo/)
    end

    it 'el fondo que queda lo hereda el turno siguiente: nadie lo declara de nuevo' do
      cerrar!(contado: 215, efectivo: 58_500, fondo: 50_000, como: admin)

      sign_in_as(ana)
      get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers
      expect(JSON.parse(response.body)['fondo_sugerido']).to eq(50_000.0)
    end

    it 'sin decir cuánto queda, no se retira nada' do
      cerrar!(contado: 215, efectivo: 58_500)

      expect(MovimientoContable.unscoped.where(club_id: club.id, categoria: 'retiro_caja').count).to eq(0)
    end

    # El que atiende cierra, pero no se lleva la recaudación: eso queda a nombre de quien
    # responde por la plata.
    it 'el dispensador no puede llevarse el retiro' do
      body = cerrar!(contado: 215, efectivo: 58_500, fondo: 50_000, como: ana)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/administrador o supervisor/i)
    end

    it 'el dispensador sí puede cerrar dejando todo como fondo' do
      cerrar!(contado: 215, efectivo: 58_500, fondo: 58_500, como: ana)

      expect(response).to have_http_status(:ok)
      expect(MovimientoContable.unscoped.where(club_id: club.id, categoria: 'retiro_caja').count).to eq(0)
    end

    it 'no se puede dejar de fondo más de lo que se contó' do
      body = cerrar!(contado: 215, efectivo: 58_500, fondo: 99_999, como: admin)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/no puede ser mayor a lo contado/i)
    end

    # El orden importa: si el retiro saliera antes del arqueo, contaría como salida del turno y
    # bajaría lo esperado.
    it 'la diferencia de arqueo se mide antes del retiro' do
      cerrar!(contado: 215, efectivo: 58_000, fondo: 50_000, como: admin)

      caja = CajaTurno.unscoped.where(club_id: club.id).last
      expect(caja.efectivo_esperado_ars).to eq(58_500.0)
      expect(caja.diferencia_ars).to eq(-500.0)
    end
  end

  describe 'quién cierra' do
    before { abrir!(cantidad: 300) }

    it 'lo cierra el que atendió, sin esperar al admin' do
      cerrar!(contado: 300, efectivo: 50_000, como: ana)

      expect(response).to have_http_status(:ok)
      turno = TurnoMostrador.unscoped.where(club_id: club.id).last
      expect(turno.estado).to eq('cerrado')
      expect(turno.cerrado_por_id).to eq(ana.id)
      expect(turno.caja_turno.reload).to be_cerrada
    end

    it 'cerrado, se puede volver a abrir: cerrar y reabrir ES el arqueo' do
      cerrar!(contado: 300, efectivo: 50_000)
      abrir!(cantidad: 300, fondo: nil)

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['items'].first['heredada']).to eq(300.0)
    end
  end

  # El mostrador no es una opción que se prende: es dónde opera el que atiende. Sin turno
  # abierto no dispensa, y sólo dispensa lo que está sobre la mesa.
  describe 'sin mostrador abierto no se dispensa' do
    it 'con el mostrador cerrado, rechaza' do
      expect { dispensar!(10) }.to raise_error(ActiveRecord::RecordInvalid, /mostrador está cerrado/i)
    end

    it 'con el mostrador abierto, dispensa normal' do
      abrir!(cantidad: 300)

      expect { dispensar!(10) }.not_to raise_error
    end

    # El candado de verdad: sin esto, con el mostrador abierto y vacío se dispensaba cualquier
    # cosa del depósito por API, y la pantalla lo escondía nomás.
    it 'no se dispensa lo que está en el depósito y no sobre la mesa' do
      otro = ActsAsTenant.with_tenant(club) do
        create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'preroll', unidad: 'un',
                       cantidad: 50, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
      end
      abrir!(cantidad: 300) # sólo la flor sube a la mesa

      expect {
        ActsAsTenant.with_tenant(club) do
          Dispensacion.create!(paciente: paciente, user: ana, stock: otro, sede: sede, cantidad: 2,
                               medio_pago: 'efectivo', aporte_socio_ars: 200,
                               fecha_dispensacion: Time.zone.today)
        end
      }.to raise_error(ActiveRecord::RecordInvalid, /No está sobre el mostrador/i)
    end

    # El mostrador controla a quien ATIENDE. El admin es el que lo carga y lo arquea: es el dueño
    # de la mercadería, y pedirle turno abierto para registrar una dispensa vieja sería fricción
    # sin control detrás.
    it 'el admin dispensa sin mostrador' do
      expect {
        ActsAsTenant.with_tenant(club) do
          Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                               cantidad: 10, medio_pago: 'efectivo', aporte_socio_ars: 1_000,
                               fecha_dispensacion: Time.zone.today)
        end
      }.not_to raise_error
    end
  end
end
