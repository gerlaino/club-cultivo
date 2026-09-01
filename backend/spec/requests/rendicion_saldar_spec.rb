require 'rails_helper'

# LO QUE EL REPARTIDOR SE QUEDÓ Y DESPUÉS DEVUELVE.
#
# Cuando rinde $100.000 y sobre la mesa aparecen $80.000, los $20.000 quedan a su nombre. Hasta
# acá eso se acumulaba PARA SIEMPRE: no había forma de decir "ya la devolvió", y el propio
# repartidor no veía en ningún lado cuánto tenía anotado — tenía que preguntar.
#
# "Rendir en partes" —entregar hoy la mitad y mañana el resto— es exactamente esto: se rinde
# todo, se recibe lo que trajo, y lo que faltó se salda después.
RSpec.describe 'Devolver lo que quedó a cuenta', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:juan)  { create(:user, :delivery, club: club, first_name: 'Juan') }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 1_000, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  # Juan cobró $100.000 en la puerta y sobre la mesa puso $80.000.
  before do
    ActsAsTenant.with_tenant(club) do
      d = Dispensacion.create!(paciente: create(:paciente, club: club), user: admin, stock: stock,
                               sede: sede, cantidad: 10, medio_pago: 'efectivo',
                               aporte_socio_ars: 100_000, fecha_dispensacion: Time.zone.today,
                               con_envio: true, delivery_id: juan.id,
                               direccion_envio: 'Falsa 123', contacto_nombre: 'X')
      Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: juan,
                                          medio: 'efectivo', monto: 100_000, contexto: 'entrega')
    end

    sign_in_as(juan)
    post '/api/rendiciones', headers: auth_headers, params: { receptor_id: admin.id }
    id = JSON.parse(response.body)['id']
    sign_in_as(admin)
    post "/api/rendiciones/#{id}/recibir", headers: auth_headers,
         params: { monto_recibido_ars: 80_000, motivo: 'trajo 80, el resto lo trae mañana' }
  end

  def saldo_de(u) = Rendiciones::SaldarACuenta.saldo_de(club, u)

  def saldar!(monto, como: admin, de: nil)
    sign_in_as(como)
    post '/api/rendiciones/saldar', headers: auth_headers,
         params: { delivery_id: (de || juan).id, monto_ars: monto }
    JSON.parse(response.body)
  end

  it 'lo que faltó queda a su nombre' do
    expect(saldo_de(juan)).to eq(20_000)
  end

  # No lo veía en ningún lado: se lo mostramos donde ya mira sus rendiciones.
  it 'y él lo ve, sin preguntarle a nadie' do
    sign_in_as(juan)
    get '/api/rendiciones', headers: auth_headers

    expect(JSON.parse(response.body)['mi_saldo_ars']).to eq(20_000.0)
  end

  describe 'cuando trae el resto' do
    it 'el saldo vuelve a cero' do
      body = saldar!(20_000)

      expect(response).to have_http_status(:ok)
      expect(body['saldo_ars']).to eq(0.0)
      expect(saldo_de(juan)).to eq(0)
    end

    it 'se puede devolver de a poco' do
      saldar!(5_000)

      expect(saldo_de(juan)).to eq(15_000)
    end

    # La plata entra al cajón de verdad: si no, el arqueo de la noche la encuentra de más.
    it 'la plata entra a la caja abierta' do
      turno = abrir_mostrador!(sede, usuario: admin, recibe: create(:user, :dispensador, club: club))
      caja  = turno.caja_turno
      antes = caja.efectivo_esperado_ars.to_d

      saldar!(20_000)

      expect(caja.reload.efectivo_esperado_ars.to_d - antes).to eq(20_000)
    end

    it 'no se devuelve más de lo que debe' do
      body = saldar!(25_000)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/Sólo tiene \$20000/)
      expect(saldo_de(juan)).to eq(20_000)
    end

    it 'ni de quien no debe nada' do
      otro = create(:user, :delivery, club: club)
      body = saldar!(1_000, de: otro)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/no tiene nada a cuenta/i)
    end

    it 'ni $0' do
      saldar!(0)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # Que la devolvió NO lo puede declarar él: sería firmar su propio recibo.
  it 'lo registra quien la recibe, no el repartidor' do
    saldar!(20_000, como: juan)

    expect(response).to have_http_status(:forbidden)
    expect(saldo_de(juan)).to eq(20_000)
  end

  it 'queda a nombre de quien la trajo y de quien la recibió' do
    saldar!(20_000)

    mov = club.movimientos_contables.where(categoria: 'devolucion_a_cuenta').last
    expect(mov.retirado_por_id).to eq(juan.id)
    expect(mov.created_by_id).to eq(admin.id)
    expect(mov.descripcion).to match(/Devolución de Juan/)
  end
end
