require 'rails_helper'

RSpec.describe 'ARICCAME — transmisión (simulada)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def registro(estado: 'pendiente', intentos: 0)
    AriccameRegistro.create!(club: club, tipo: 'dispensacion', estado: estado, intentos: intentos, payload: { x: 1 })
  end

  it 'reenviar transmite un pendiente y lo deja confirmado con código' do
    r = registro
    sign_in_as(admin)
    post "/ariccame_registros/#{r.id}/reenviar", headers: auth_headers
    expect(response).to have_http_status(:ok)
    r.reload
    expect(r.estado).to eq('confirmado')
    expect(r.codigo_ariccame).to be_present
    expect(r.confirmado_at).to be_present
  end

  it 'transmitir_pendientes procesa pendientes y errores reintentables' do
    registro(estado: 'pendiente')
    registro(estado: 'error', intentos: 1)
    registro(estado: 'error', intentos: 3)   # sin reintentos → no se procesa
    registro(estado: 'confirmado')           # ya confirmado → no se procesa
    sign_in_as(admin)

    post '/ariccame_registros/transmitir_pendientes', headers: auth_headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['confirmados']).to eq(2)
    expect(club.ariccame_registros.confirmados.count).to eq(3)  # 2 nuevos + el ya confirmado
  end

  it 'rechaza re-confirmar un registro ya confirmado' do
    r = registro(estado: 'confirmado')
    sign_in_as(admin)
    post "/ariccame_registros/#{r.id}/reenviar", headers: auth_headers
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
