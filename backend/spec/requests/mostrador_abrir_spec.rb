require 'rails_helper'

# Abrir el mostrador: la mercadería que queda sobre la mesa hoy.
#
# La regla que ordena todo esto: el mostrador APARTA, no descuenta. Es la mecánica del apartado
# de un evento con otro destinatario — la fila `Stock` sigue siendo una sola, con su ST-xx y su
# QR, porque lo trazable sale del inventario por dispensación y nunca por cambiar de mesa.
#
# Y el corolario que no se puede romper: si aparta pero la dispensa no lo imputa, el stock
# cargado se vuelve indispensable y el disponible cae el doble. Es exactamente el bug que ya
# había pasado con los eventos, y por eso está probado acá abajo.
RSpec.describe 'Abrir el mostrador', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:northern) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                     unidad: 'g', cantidad: 500, estado: 'asignado', disponibilidad: 'ambas',
                     precio_sugerido_ars: 100)
    end
  end

  def abrir!(items:, fondo: 10_000, como: admin)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/abrir", headers: auth_headers,
         params: { monto_inicial_ars: fondo, items: items }
    JSON.parse(response.body)
  end

  def ver(como = admin)
    sign_in_as(como)
    get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers
    JSON.parse(response.body)
  end

  describe 'el apartado' do
    it 'aparta lo cargado: bloquea sin descontar' do
      abrir!(items: [{ stock_id: northern.id, cantidad: 300 }])

      expect(response).to have_http_status(:created)
      # La mercadería no se movió del inventario: sigue habiendo 500 g de ese lote.
      expect(northern.reload.cantidad.to_f).to eq(500.0)
      # Pero 300 están sobre la mesa y nadie más los ve libres.
      expect(northern.apartado_para_mostrador.to_f).to eq(300.0)
      expect(northern.cantidad_disponible_real.to_f).to eq(200.0)
    end

    it 'no deja poner sobre la mesa más de lo que hay libre' do
      body = abrir!(items: [{ stock_id: northern.id, cantidad: 900 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/No hay tanto/i)
      expect(TurnoMostrador.unscoped.count).to eq(0)
    end

    # Lo reservado a un paciente está en el mismo frasco, pero tiene dueño.
    it 'no deja subir a la mesa lo que ya está reservado para un paciente' do
      ActsAsTenant.with_tenant(club) do
        Reserva.create!(club: club, paciente: create(:paciente, club: club), stock: northern,
                        user: admin, cantidad: 400, fecha_entrega_estimada: Time.zone.tomorrow)
      end

      body = abrir!(items: [{ stock_id: northern.id, cantidad: 300 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/quedan 100/i)
    end

    it 'un stock no habilitado para dispensa no sube a la mesa' do
      northern.update!(disponibilidad: 'produccion')

      body = abrir!(items: [{ stock_id: northern.id, cantidad: 10 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/no está habilitado para dispensa/i)
    end

    it 'un stock de otra sede no sube a esta mesa' do
      otra = create(:sede, club: club, tipo: 'social', nombre: 'Norte')
      northern.update!(sede: otra)

      body = abrir!(items: [{ stock_id: northern.id, cantidad: 10 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/no está asignado a esta sede/i)
    end
  end

  describe 'el turno' do
    it 'lo abre el que va a atender: no hace falta que esté el admin' do
      abrir!(items: [{ stock_id: northern.id, cantidad: 100 }], como: ana)

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['abierto_por']).to eq(ana.nombre_completo)
    end

    it 'uno solo por mostrador' do
      abrir!(items: [{ stock_id: northern.id, cantidad: 100 }])
      body = abrir!(items: [{ stock_id: northern.id, cantidad: 50 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/ya hay un turno abierto/i)
    end

    it 'abre la caja de plata con el fondo, en el mismo gesto' do
      body = abrir!(items: [{ stock_id: northern.id, cantidad: 100 }], fondo: 25_000)

      caja = CajaTurno.unscoped.find(body['caja_turno_id'])
      expect(caja.monto_inicial_ars.to_f).to eq(25_000.0)
      expect(caja.punto_type).to eq('Mostrador')
      expect(caja).to be_abierta
    end

    # Dos cajas activas sobre el mismo cajón partirían el arqueo en dos por la misma plata.
    it 'si ya había una caja abierta la reusa en vez de abrir otra' do
      caja = ActsAsTenant.with_tenant(club) do
        CajaTurno.create!(club: club, sede: sede, punto: sede.mostrador!, abierta_por: admin,
                          monto_inicial_ars: 7_000, abierta_at: 1.hour.ago, estado: 'abierta')
      end

      body = abrir!(items: [{ stock_id: northern.id, cantidad: 100 }], fondo: 99_999)

      expect(body['caja_turno_id']).to eq(caja.id)
      expect(CajaTurno.unscoped.where(club_id: club.id).count).to eq(1)
    end
  end

  describe 'la herencia del cierre anterior' do
    let!(:anterior) do
      ActsAsTenant.with_tenant(club) do
        t = TurnoMostrador.create!(club: club, mostrador: sede.mostrador!, estado: 'cerrado',
                                   abierto_por: ana, abierto_at: 1.day.ago,
                                   cerrado_por: ana, cerrado_at: 12.hours.ago)
        t.items.create!(club: club, stock: northern, cantidad_apertura: 300,
                        cantidad_dispensada: 85, cantidad_cierre: 215)
        t
      end
    end

    it 'sugiere abrir con lo que se contó anoche' do
      sugerido = ver['sugerido']

      expect(sugerido.size).to eq(1)
      expect(sugerido.first['stock_id']).to eq(northern.id)
      expect(sugerido.first['cantidad']).to eq(215.0)
    end

    # El número de partida lo calcula el backend. Si lo mandara el cliente, cualquiera podría
    # declarar con cuánto arranca y borrar la diferencia de un plumazo.
    it 'guarda lo que dejó el anterior aunque el que abre declare otra cosa' do
      body = abrir!(items: [{ stock_id: northern.id, cantidad: 211 }])
      item = body['items'].first

      expect(item['heredada']).to eq(215.0)
      expect(item['apertura']).to eq(211.0)
      expect(item['diferencia_apertura']).to eq(-4.0)
      expect(body['hubo_correccion_apertura']).to be(true)
      expect(TurnoMostrador.unscoped.find(body['id']).turno_anterior_id).to eq(anterior.id)
    end

    it 'sin corrección no hay diferencia que mirar' do
      body = abrir!(items: [{ stock_id: northern.id, cantidad: 215 }])

      expect(body['items'].first['diferencia_apertura']).to eq(0.0)
      expect(body['hubo_correccion_apertura']).to be(false)
    end
  end

  # Lo que no se puede romper: el mostrador aparta, la dispensa descuenta, y el bloqueo se libera
  # en la misma medida. Si no se imputa, baja `cantidad` Y sigue apartado — el disponible cae el
  # doble y el stock cargado se vuelve indispensable.
  describe 'dispensar desde el mostrador' do
    let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

    before { abrir!(items: [{ stock_id: northern.id, cantidad: 300 }]) }

    def dispensar!(cantidad)
      ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: paciente, user: admin, stock: northern, sede: sede,
                             cantidad: cantidad, medio_pago: 'efectivo', aporte_socio_ars: 1_000,
                             fecha_dispensacion: Time.zone.today)
      end
    end

    it 'descuenta una sola vez' do
      dispensar!(50)

      expect(northern.reload.cantidad.to_f).to eq(450.0)      # 500 − 50
      expect(northern.apartado_para_mostrador.to_f).to eq(250.0) # 300 − 50
      expect(northern.cantidad_disponible_real.to_f).to eq(200.0) # 450 − 250, igual que antes
    end

    it 'lo imputa al ítem del turno, que es donde se ve qué salió de la mesa' do
      dispensar!(50)

      item = sede.mostrador!.turno_abierto.items.first
      expect(item.cantidad_dispensada.to_f).to eq(50.0)
      expect(item.esperado.to_f).to eq(250.0)
    end

    it 'deja el turno anotado en la dispensa' do
      d = dispensar!(10)

      expect(d.turno_mostrador_id).to eq(sede.mostrador!.turno_abierto.id)
    end

    # Se puede dispensar TODO lo que está sobre la mesa: para el mostrador que lo cargó, lo
    # apartado no es un bloqueo, es su stock.
    it 'se puede dispensar hasta el último gramo de lo cargado' do
      expect { dispensar!(300) }.not_to raise_error
      expect(northern.reload.cantidad.to_f).to eq(200.0)
    end
  end

  describe 'aislamiento entre organizaciones' do
    it 'no se puede subir a la mesa el stock de otra organización' do
      otro  = create(:club)
      ajeno = ActsAsTenant.with_tenant(otro) do
        otra_sede = create(:sede, club: otro, tipo: 'social')
        otro_lote = create(:lote, club: otro, sala: create(:sala, club: otro, sede: otra_sede))
        create(:stock, club: otro, sede: otra_sede, lote: otro_lote, forma_producto: 'flor_seca',
                       unidad: 'g', cantidad: 500, estado: 'asignado', disponibilidad: 'ambas')
      end

      body = abrir!(items: [{ stock_id: ajeno.id, cantidad: 10 }])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/no existe en la organización/i)
    end

    it 'no se puede abrir el mostrador de otra organización' do
      otro      = create(:club)
      otra_sede = ActsAsTenant.with_tenant(otro) { create(:sede, club: otro, tipo: 'social') }

      sign_in_as(admin)
      post "/api/sedes/#{otra_sede.id}/mostrador/abrir", headers: auth_headers,
           params: { monto_inicial_ars: 1_000, items: [] }

      expect(response).to have_http_status(:not_found)
    end
  end
end
