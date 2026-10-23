require 'rails_helper'

# AC (22-oct-2026, Germán): «hice un pedido para un usuario nuevo desde un club… está en consultas,
# pero no hay nada que me indique que tengo una consulta sin leer». El super admin ve cuántas hay
# sin atender (en la barra y en el Inicio); contestar o marcar atendida la descuenta; nadie más lo ve.
RSpec.describe 'Consultas pendientes', type: :request do
  let!(:super_admin) { create(:user, :super_admin) }
  let!(:nueva)    { SolicitudContacto.create!(tipo: 'organizacion', nombre: 'Ana', email: 'ana@ong.org', mensaje: 'Un usuario más') }
  let!(:atendida) { SolicitudContacto.create!(tipo: 'organizacion', nombre: 'Beto', email: 'b@ong.org', mensaje: 'x', atendida_at: 1.day.ago) }

  it 'cuenta sólo las que nadie atendió, y marcarla atendida la descuenta' do
    sign_in_as(super_admin)
    get '/api/super_admin/consultas/pendientes'
    expect(response.parsed_body).to eq('pendientes' => 1)

    patch "/api/super_admin/consultas/#{nueva.id}", params: { atendida: true }, as: :json
    get '/api/super_admin/consultas/pendientes'
    expect(response.parsed_body).to eq('pendientes' => 0)
  end

  it 'el Inicio trae la misma cuenta' do
    sign_in_as(super_admin)
    get '/api/super_admin/pulso'
    expect(response.parsed_body['consultas_pendientes']).to eq(1)
  end

  it 'el admin de una organización no la ve' do
    sign_in_as(create(:user, :admin, club: create(:club)))
    get '/api/super_admin/consultas/pendientes'
    expect(response).to have_http_status(:forbidden)
  end
end
