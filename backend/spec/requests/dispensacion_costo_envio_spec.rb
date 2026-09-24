require 'rails_helper'

# EL VALOR DEL ENVÍO (Germán, 23-sep-2026).
#
# AC:
#   · Al crear una dispensa con delivery hay un campo «valor del envío» que se completa en ese
#     momento. Lo puede cargar quien hace la dispensa, dispensador incluido.
#   · Se SUMA al total de la dispensa, bien diferenciado del producto.
#   · 0 se permite: es el envío bonificado. Negativo, no.
#   · La plata del envío es de la organización y va a su propia categoría: «Envíos», como la de
#     la dispensación va a «Recupero dispensación».
#   · (Opción A) El envío va dentro del total: cobros, contra entrega, arqueo y rendición no
#     cambian. El descuento del paciente no se aplica al envío.
RSpec.describe 'Dispensación con valor de envío', type: :request do
  include AuthHelpers

  let(:club)        { create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true }) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }
  let(:juan)        { create(:user, :delivery, club: club, first_name: 'Juan') }
  let(:sede)        { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin, domicilio_calle: 'Calle', domicilio_altura: '1', domicilio_ciudad: 'CABA') }
  # 10 g a $100 = $1.000 de producto.
  let!(:stock) { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 1_000, precio_sugerido_ars: 100) }

  def json = JSON.parse(response.body)

  def dispensar(como: admin, envio: :no_mandar, **extra)
    sign_in_as(como)
    body = { stock_id: stock.id, cantidad: 10, con_envio: true, delivery_id: juan.id, direccion_origen: 'domicilio' }
    body[:costo_envio_ars] = envio unless envio == :no_mandar
    post "/api/pacientes/#{paciente.id}/dispensaciones", params: { dispensacion: body.merge(extra) }, as: :json
  end

  def por_categoria(d)
    MovimientoContable.unscoped.where(dispensacion_id: d.id, deleted_at: nil).group(:categoria).sum(:monto_ars).transform_values(&:to_d)
  end

  describe 'al crear' do
    it 'se suma al total, diferenciado del producto' do
      dispensar(envio: 500, medio_pago: 'efectivo')

      expect(response).to have_http_status(:created), response.body
      expect(json['aporte_socio_ars']).to eq(1_500.0)
      expect(json['costo_envio_ars']).to eq(500.0)
      expect(json['subtotal_productos_ars']).to eq(1_000.0)
      expect(json['envio_bonificado']).to be(false)
    end

    it 'es obligatorio con envío' do
      dispensar(medio_pago: 'efectivo')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to match(/valor del envío/)
      expect(Dispensacion.count).to eq(0)
    end

    it 'en 0 es el envío bonificado' do
      dispensar(envio: 0, medio_pago: 'efectivo')

      expect(response).to have_http_status(:created), response.body
      expect(json['aporte_socio_ars']).to eq(1_000.0)
      expect(json['envio_bonificado']).to be(true)
    end

    it 'negativo, no' do
      dispensar(envio: -100, medio_pago: 'efectivo')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Dispensacion.count).to eq(0)
    end

    it 'lo carga también el dispensador' do
      abrir_mostrador!(sede, usuario: admin, recibe: dispensador)
      dispensar(como: dispensador, envio: 700, medio_pago: 'efectivo')

      expect(response).to have_http_status(:created), response.body
      expect(json['costo_envio_ars']).to eq(700.0)
    end

    it 'el descuento del paciente no toca el envío' do
      paciente.update!(descuento_porcentaje: 50)
      dispensar(envio: 500, medio_pago: 'efectivo')

      expect(json['subtotal_productos_ars']).to eq(500.0) # $1.000 con 50 %
      expect(json['aporte_socio_ars']).to eq(1_000.0)    # + el envío entero
    end

    it 'sin envío no hay valor de envío, aunque la pantalla lo mande' do
      sign_in_as(admin)
      post "/api/pacientes/#{paciente.id}/dispensaciones", as: :json,
           params: { dispensacion: { stock_id: stock.id, cantidad: 10, medio_pago: 'efectivo', costo_envio_ars: 500 } }

      expect(json['costo_envio_ars']).to be_nil
      expect(json['aporte_socio_ars']).to eq(1_000.0)
    end

    it 'un regalo no cobra el envío' do
      dispensar(envio: 500, es_regalo: true)

      expect(response).to have_http_status(:created), response.body
      expect(json['aporte_socio_ars']).to eq(0.0)
      expect(json['envio_bonificado']).to be(true)
    end
  end

  describe 'en el libro: el envío va a «Envíos»' do
    it 'pagado entero al crear' do
      dispensar(envio: 500, medio_pago: 'efectivo')
      d = Dispensacion.find(json['id'])

      expect(por_categoria(d)).to eq('dispensacion' => 1_000, 'envio' => 500)
      expect(MovimientoContable.unscoped.find_by(dispensacion_id: d.id, categoria: 'envio').tipo).to eq('ingreso')
    end

    # Los cobros no dicen qué pagan: cada uno se reparte en proporción, y entre todos dan exacto.
    it 'una parte ahora y el resto en la puerta: entre los dos cobros, exacto' do
      dispensar(envio: 500, cobrar_en_entrega: true, cobros: [{ medio: 'transferencia', monto: 600 }])
      d = Dispensacion.find(json['id'])
      expect(d.saldo_pendiente).to eq(900)

      sign_in_as(juan)
      patch "/api/dispensaciones/#{d.id}/iniciar_viaje", as: :json
      patch "/api/dispensaciones/#{d.id}/entregar", as: :json,
            params: { cobros: [{ medio: 'transferencia', monto: 900 }] }
      expect(response).to have_http_status(:ok), response.body

      expect(por_categoria(d)).to eq('dispensacion' => 1_000, 'envio' => 500)
    end

    it 'contra entrega en efectivo: se parte al recibir la rendición' do
      dispensar(envio: 500, cobrar_en_entrega: true)
      d = Dispensacion.find(json['id'])

      sign_in_as(juan)
      patch "/api/dispensaciones/#{d.id}/iniciar_viaje", as: :json
      patch "/api/dispensaciones/#{d.id}/entregar", as: :json, params: { cobros: [{ medio: 'efectivo', monto: 1_500 }] }
      expect(por_categoria(d)).to eq({}) # en tránsito: se asienta al rendir
      post '/api/rendiciones', params: { receptor_id: admin.id }
      id = json['id']

      sign_in_as(admin)
      post "/api/rendiciones/#{id}/recibir", params: { destino: 'club' }
      expect(response).to have_http_status(:ok), response.body

      expect(por_categoria(d)).to eq('dispensacion' => 1_000, 'envio' => 500)
    end

    it 'a cuenta corriente (sin cobros), también partido' do
      paciente.cuenta_corriente!.update!(limite_credito: 10_000)
      dispensar(envio: 500, medio_pago: 'cuenta_corriente')
      d = Dispensacion.find(json['id'])

      expect(por_categoria(d)).to eq('dispensacion' => 1_000, 'envio' => 500)
    end
  end

  # La plata del envío también entró: si el paquete no llega, queda a favor con el resto.
  it 'si el paquete no se entrega, el envío pagado queda a favor con lo demás' do
    dispensar(envio: 500, medio_pago: 'transferencia')
    d = Dispensacion.find(json['id'])

    patch "/api/dispensaciones/#{d.id}/cancelar_entrega", as: :json

    expect(response).to have_http_status(:ok), response.body
    expect(paciente.cuenta_corriente.reload.saldo_disponible).to eq(1_500)
  end

  describe 'al editar' do
    it 'cambiar la cantidad conserva el envío' do
      dispensar(envio: 500, medio_pago: 'efectivo')
      d = Dispensacion.find(json['id'])

      patch "/api/dispensaciones/#{d.id}", as: :json,
            params: { dispensacion: { items: [{ stock_id: stock.id, cantidad: 20 }] } }

      expect(response).to have_http_status(:ok), response.body
      expect(json['aporte_socio_ars']).to eq(2_500.0)
      expect(json['costo_envio_ars']).to eq(500.0)
      expect(por_categoria(d)).to eq('dispensacion' => 2_000, 'envio' => 500)
    end

    it 'cambiar el valor del envío cambia el total' do
      dispensar(envio: 500, medio_pago: 'efectivo')
      d = Dispensacion.find(json['id'])

      patch "/api/dispensaciones/#{d.id}", as: :json, params: { dispensacion: { costo_envio_ars: 0 } }

      expect(response).to have_http_status(:ok), response.body
      expect(json['aporte_socio_ars']).to eq(1_000.0)
      expect(json['envio_bonificado']).to be(true)
      expect(por_categoria(d)).to eq('dispensacion' => 1_000)
    end
  end

  # Se dispensó sin envío y después se manda: lo cobrado no se toca; el envío, si cuesta, lo
  # cobra el repartidor en la puerta.
  describe 'mandar después por delivery' do
    def sin_envio!
      sign_in_as(admin)
      post "/api/pacientes/#{paciente.id}/dispensaciones", as: :json,
           params: { dispensacion: { stock_id: stock.id, cantidad: 10, medio_pago: 'efectivo' } }
      Dispensacion.find(json['id'])
    end

    it 'con valor: se suma y queda para cobrar en la puerta' do
      d = sin_envio!
      patch "/api/dispensaciones/#{d.id}/agregar_envio", as: :json,
            params: { dispensacion: { delivery_id: juan.id, direccion_origen: 'domicilio', costo_envio_ars: 400 } }

      expect(response).to have_http_status(:ok), response.body
      d.reload
      expect(d.aporte_socio_ars).to eq(1_400)
      expect(d.saldo_pendiente).to eq(400)
      expect(d.cobrar_en_entrega).to be(true)
    end

    it 'también pide el valor' do
      d = sin_envio!
      patch "/api/dispensaciones/#{d.id}/agregar_envio", as: :json,
            params: { dispensacion: { delivery_id: juan.id, direccion_origen: 'domicilio' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(d.reload.con_envio).to be(false)
    end
  end
end
