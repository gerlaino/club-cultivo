require 'rails_helper'

# «Eliminar» se retiró: la única puerta es anular con motivo, y el dispensador puede —pero sólo
# las que salieron por su sede.
RSpec.describe 'PATCH /dispensaciones/:id/anular', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:ana)      { create(:user, :dispensador, club: club) }
  let(:centro)   { create(:sede, club: club, tipo: 'mixta') }
  let(:norte)    { create(:sede, club: club, tipo: 'mixta') }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }

  def stock_en(sede)
    ActsAsTenant.with_tenant(club) do
      lote = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 100, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  def dispensa_en(sede)
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock_en(sede), sede: sede,
                           cantidad: 5, medio_pago: 'efectivo', aporte_socio_ars: 500,
                           fecha_dispensacion: Time.zone.today)
    end
  end

  before { UserSede.create!(user: ana, sede: centro) }

  it 'el dispensador anula una de su mostrador, con motivo' do
    d = dispensa_en(centro)
    sign_in_as(ana)
    patch "/dispensaciones/#{d.id}/anular", params: { motivo: 'devolucion', nota: 'se arrepintió' }, as: :json
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['anulada']).to be true
    expect(body.dig('anulacion', 'motivo')).to eq('devolucion')
    expect(body.dig('anulacion', 'motivo_label')).to eq('Devolución del paciente')
    expect(body.dig('anulacion', 'nota')).to eq('se arrepintió')
    expect(body.dig('anulacion', 'con_devolucion')).to be true
  end

  it 'el dispensador NO anula una de otra sede' do
    d = dispensa_en(norte)
    sign_in_as(ana)
    patch "/dispensaciones/#{d.id}/anular", params: { motivo: 'error_carga' }, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(d.reload.cancelada?).to be false
  end

  it 'sin motivo no se anula' do
    d = dispensa_en(centro)
    sign_in_as(admin)
    patch "/dispensaciones/#{d.id}/anular", params: { nota: 'x' }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to include('por qué')
  end

  it 'el motivo del repartidor no se elige a mano' do
    d = dispensa_en(centro)
    sign_in_as(admin)
    patch "/dispensaciones/#{d.id}/anular", params: { motivo: 'no_entregado' }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'no se anula dos veces' do
    d = dispensa_en(centro)
    sign_in_as(admin)
    patch "/dispensaciones/#{d.id}/anular", params: { motivo: 'error_carga' }, as: :json
    patch "/dispensaciones/#{d.id}/anular", params: { motivo: 'error_carga' }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'borrar ya no existe' do
    expect { Rails.application.routes.recognize_path('/api/dispensaciones/1', method: :delete) }
      .to raise_error(ActionController::RoutingError)
  end
end
