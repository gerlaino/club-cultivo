require 'rails_helper'

RSpec.describe 'GET /api/usuarios/:id/stats', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:manicura) { create(:user, :manicura, club: club) }

  it 'devuelve horas, producción y dispensaciones del usuario en el mes' do
    JornadaLaboral.create!(club: club, user: manicura, fecha: Date.current, hora_entrada: '09:00', hora_salida: '17:00')
    sign_in_as(admin)

    get "/api/usuarios/#{manicura.id}/stats", params: { anio: Date.current.year, mes: Date.current.month }
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['usuario']['id']).to eq(manicura.id)
    expect(body['horas']['total']).to eq(8.0)
    expect(body['horas']['dias']).to eq(1)
    expect(body).to have_key('produccion')
    expect(body).to have_key('despachos')
    expect(body).to have_key('dispensaciones')
  end

  it 'no permite a un no-admin' do
    sign_in_as(manicura)
    get "/api/usuarios/#{manicura.id}/stats"
    expect(response).to have_http_status(:forbidden)
  end

  it 'no permite ver stats de un usuario de otro club' do
    otro = create(:club); otro_user = create(:user, :manicura, club: otro)
    sign_in_as(admin)
    get "/api/usuarios/#{otro_user.id}/stats"
    expect(response).to have_http_status(:not_found)
  end
end
