require 'rails_helper'

# El informe de sedes (auditoría → sedes) cuenta SOLO salas de cultivo. Las salas de proceso
# post-cosecha (cosecha/secado/curado) son legacy del flujo viejo y no deben contar.
RSpec.describe 'Informe de sedes — conteo de salas', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club) }

  it 'cuenta solo las salas de cultivo, ignorando las de proceso post-cosecha' do
    create(:sala, club: club, sede: sede, kind: 'vegetativo')
    create(:sala, club: club, sede: sede, kind: 'floracion')
    create(:sala, club: club, sede: sede, kind: 'cosecha')   # legacy — no debe contar
    sign_in_as(admin)

    get '/informes/sedes', headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    expect(body['salas_totales']).to eq(2)
    fila = body['por_sede'].find { |s| s['nombre'] == sede.nombre }
    expect(fila['salas']).to eq(2)
  end
end
