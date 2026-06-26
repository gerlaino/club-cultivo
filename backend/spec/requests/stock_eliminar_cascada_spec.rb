require 'rails_helper'

RSpec.describe 'DELETE /stocks/:id — cascada a derivados', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  before { sign_in_as(admin) }

  def producir_derivado(origen, gramos: 80, cantidad: 8)
    post "/stocks/#{origen.id}/producir",
         params: { gramos_usados: gramos, forma_producto: 'prensado', cantidad_producida: cantidad, unidad: 'un', precio_sugerido_ars: 100 },
         headers: auth_headers, as: :json
    Stock.find(JSON.parse(response.body)['id'])
  end

  it 'borra el stock y sus derivados en cascada' do
    origen   = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    derivado = producir_derivado(origen)

    delete "/stocks/#{origen.id}", headers: auth_headers, as: :json
    expect(response).to have_http_status(:no_content)
    expect(Stock.where(id: origen.id)).to be_empty
    expect(Stock.where(id: derivado.id)).to be_empty   # derivado borrado también
  end

  it 'bloquea todo el borrado si un derivado tiene un despacho entregado' do
    origen   = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    derivado = producir_derivado(origen)

    disp = Dispensacion.create!(
      paciente: paciente, user: admin, stock: derivado, sede: sede,
      cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Date.today, aporte_socio_ars: 100,
    )
    disp.update_column(:estado_envio, 'entregado')

    delete "/stocks/#{origen.id}", headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to include('entregados')
    expect(Stock.where(id: origen.id)).to exist     # nada se borró
    expect(Stock.where(id: derivado.id)).to exist
  end

  it 'bloquea si un derivado tiene un despacho EN CAMINO (en_viaje)' do
    origen   = create(:stock, :externo, club: club, sede: sede, forma_producto: 'flor_seca', cantidad: 200, costo_unitario_ars: 3)
    derivado = producir_derivado(origen)

    disp = Dispensacion.create!(
      paciente: paciente, user: admin, stock: derivado, sede: sede,
      cantidad: 1, medio_pago: 'efectivo', fecha_dispensacion: Date.today, aporte_socio_ars: 100,
    )
    disp.update_column(:estado_envio, 'en_viaje')

    delete "/stocks/#{origen.id}", headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to include('en camino')
    expect(Stock.where(id: derivado.id)).to exist
  end
end
