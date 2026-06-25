require 'rails_helper'

# La analítica de ingresos (ejecutivo/contabilidad) debe salir del MISMO libro de
# caja que el dashboard de Negocio, de modo que una seña (aporte_socio) cuente en
# ambos lados y no haya el "10000 arriba / sin ingresos abajo".
RSpec.describe 'Analytics — ingresos desde el libro contable', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  before do
    # Una seña: ingreso de caja (aporte_socio), sin dispensación asociada.
    MovimientoContable.create!(
      club: club, sede_id: sede.id, paciente_id: paciente.id, created_by: admin,
      tipo: 'ingreso', categoria: 'aporte_socio', descripcion: 'Seña reserva #1 — test',
      monto_ars: 10_000, fecha: Time.zone.today, pagado: true, comprobante_tipo: 'sin_comprobante'
    )
    sign_in_as(admin)
  end

  it 'el resumen ejecutivo cuenta la seña en los ingresos del año' do
    get '/analytics/ejecutivo', headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig('actual', 'ingresos')).to eq(10_000.0)
  end

  it 'la contabilidad mensual cuenta la seña en los ingresos del mes en curso' do
    get '/analytics/contabilidad', headers: auth_headers
    expect(response).to have_http_status(:ok)
    meses = JSON.parse(response.body)['meses']
    mes_actual = meses.last   # el mes en curso es el último del rango de 12
    expect(mes_actual['ingresos']).to eq(10_000.0)
  end
end
