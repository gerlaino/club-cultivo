require 'rails_helper'

# AC (Germán, 20-oct-2026): «el médico, si bien puede ver las dispensaciones del paciente, no se
# le debe mostrar ningún valor de lo gastado». Y el médico sólo ve a SUS pacientes vinculados
# (6-oct) y sólo se ocupa de la salud (15-oct): no dispensa, no edita, no anula.
RSpec.describe 'El médico y las dispensaciones', type: :request do
  let(:club)   { create(:club, features: { 'produccion_dispensa' => true, 'medico' => true }) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:medico) { create(:user, club: club, role: 'medico') }
  let(:sede)   { create(:sede, club: club, created_by: admin) }
  let(:stock) do
    ActsAsTenant.with_tenant(club) do
      Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'P', forma_producto: 'flor_seca',
                    unidad: 'g', cantidad: 500, precio_sugerido_ars: 3000)
    end
  end
  let!(:suyo) do
    ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin, con_seguimiento_medico: true) }
  end
  let!(:ajeno) do
    ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin, con_seguimiento_medico: true) }
  end

  def dispensar!(paciente)
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede, cantidad: 10,
                           medio_pago: 'transferencia', precio_unitario_ars: 3000,
                           fecha_dispensacion: Time.zone.today, aporte_socio_ars: 30_000)
    end
  end

  # Todo lo que sea plata, en cualquier nivel de la respuesta.
  PLATA = /ars|precio|aporte|cobr|pago|saldo|credito|descuento|subtotal|monto|limite|envio_bonificado/

  def claves(obj, acc = [])
    case obj
    when Hash  then obj.each { |k, v| acc << k.to_s; claves(v, acc) }
    when Array then obj.each { |v| claves(v, acc) }
    end
    acc
  end

  before do
    ActsAsTenant.with_tenant(club) { MedicoPaciente.vincular!(medico: medico, paciente: suyo) }
    sign_in_as(medico)
  end

  it 've las dispensas de su paciente —qué, cuánto, cuándo— sin ningún dato de plata' do
    dispensar!(suyo)

    get "/api/pacientes/#{suyo.id}/dispensaciones"
    expect(response).to have_http_status(:ok), response.body
    json = JSON.parse(response.body)
    d = json['dispensaciones'].first

    expect(d['fecha_dispensacion']).to eq(Time.zone.today.iso8601)
    expect(d['cantidad']).to eq(10.0)
    expect(d['items'].first['stock']).to include('forma_producto' => 'flor_seca', 'unidad' => 'g')
    expect(claves(json['dispensaciones']).grep(PLATA)).to eq([])
    expect(response.body).not_to include('30000', '3000.0')
  end

  it 'la ficha de una dispensa tampoco trae plata' do
    disp = dispensar!(suyo)

    get "/api/dispensaciones/#{disp.id}"
    expect(response).to have_http_status(:ok), response.body
    expect(claves(JSON.parse(response.body)).grep(PLATA)).to eq([])
  end

  it 'no ve las dispensas de un paciente que no es suyo, ni por listado ni por id' do
    disp = dispensar!(ajeno)

    get "/api/pacientes/#{ajeno.id}/dispensaciones"
    expect(response).to have_http_status(:not_found)

    get "/api/dispensaciones/#{disp.id}"
    expect(response).to have_http_status(:not_found)
  end

  it 'no lista las dispensas de la organización (el día, los envíos) ni pide el resumen' do
    dispensar!(suyo)

    get '/api/dispensaciones'
    expect(response).to have_http_status(:forbidden)
    get '/api/dispensaciones', params: { con_envio: 'true' }
    expect(response).to have_http_status(:forbidden)
    get "/api/pacientes/#{suyo.id}/dispensaciones", params: { resumen: 'true' }
    expect(response).to have_http_status(:forbidden)
  end

  it 'no dispensa, no edita y no anula' do
    disp = dispensar!(suyo)

    post "/api/pacientes/#{suyo.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: 5, medio_pago: 'efectivo' } }, as: :json
    expect(response).to have_http_status(:forbidden)

    put "/api/dispensaciones/#{disp.id}", params: { dispensacion: { observaciones: 'x' } }, as: :json
    expect(response).to have_http_status(:forbidden)

    patch "/api/dispensaciones/#{disp.id}/anular", params: { motivo: 'error_carga' }, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(disp.reload.cancelada?).to be(false)
  end

  it 'para el admin no cambia nada: ve la plata' do
    dispensar!(suyo)
    sign_in_as(admin)

    get "/api/pacientes/#{suyo.id}/dispensaciones"
    expect(JSON.parse(response.body)['dispensaciones'].first['aporte_socio_ars']).to eq(30_000.0)
  end
end
