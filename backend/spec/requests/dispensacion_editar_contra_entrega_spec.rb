require 'rails_helper'

# AC (Germán, 17-sep-2026): al editar una dispensa que va por delivery se puede pasar el medio
# de pago a «contra entrega» (lo cobra el repartidor), y sacarlo mientras no se haya cobrado.
RSpec.describe 'Editar dispensación: contra entrega', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:delivery) { create(:user, club: club, role: 'delivery') }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin, domicilio_calle: 'Av. Siempreviva', domicilio_altura: '742', domicilio_ciudad: 'CABA') }
  let!(:stock)   { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)

  def dispensar(extra = {})
    post "/api/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 500,
                                   contacto_nombre: 'X' }.merge(extra) }, as: :json
    expect(response).to have_http_status(:created), response.body
    Dispensacion.find(json['id'])
  end

  def editar(d, attrs)
    patch "/api/dispensaciones/#{d.id}", params: { dispensacion: attrs }, as: :json
  end

  it 'una que va por delivery pagada en efectivo pasa a contra entrega: se deshace el cobro y queda pendiente' do
    d = dispensar(con_envio: true, costo_envio_ars: 0, delivery_id: delivery.id, direccion_origen: 'domicilio')
    expect(d.cobros.count).to eq(1)
    expect(d.movimientos_contables.count).to eq(1)

    editar(d, { medio_pago: 'contra_entrega' })

    expect(response).to have_http_status(:ok), response.body
    d.reload
    expect(d.cobrar_en_entrega).to     be(true)
    expect(d.cobros.count).to          eq(0)
    expect(d.movimientos_contables.count).to eq(0)
    expect(d.saldo_pendiente).to       eq(500)
  end

  it 'y vuelve a efectivo mientras el repartidor no cobró: se cobra ahora y se asienta' do
    d = dispensar(con_envio: true, costo_envio_ars: 0, delivery_id: delivery.id, direccion_origen: 'domicilio', cobrar_en_entrega: true)
    expect(d.cobrar_en_entrega).to be(true)
    expect(d.cobros).to be_empty

    editar(d, { medio_pago: 'transferencia' })

    expect(response).to have_http_status(:ok), response.body
    d.reload
    expect(d.cobrar_en_entrega).to be(false)
    expect(d.cobros.count).to      eq(1)
    expect(d.cobros.first.medio).to eq('transferencia')
    expect(d.saldo_pendiente).to   eq(0)
  end

  it 'sin envío no se puede poner contra entrega' do
    d = dispensar

    editar(d, { medio_pago: 'contra_entrega' })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json['error']).to include('por delivery')
    expect(d.reload.cobros.count).to eq(1)
  end

  it 'con el paquete ya entregado, no' do
    d = dispensar(con_envio: true, costo_envio_ars: 0, delivery_id: delivery.id, direccion_origen: 'domicilio')
    d.update_columns(estado_envio: 'entregado')

    editar(d, { medio_pago: 'contra_entrega' })

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
