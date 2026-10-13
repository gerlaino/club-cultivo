require 'rails_helper'

# AC (Germán, 12-oct-2026): el admin de la organización ya no da de alta usuarios; los crea la
# plataforma desde super admin. El admin los PIDE y el pedido cae en la bandeja de Consultas.
RSpec.describe 'Equipo: el admin pide, no da de alta', type: :request do
  include AuthHelpers
  let(:club)  { create(:club) }
  let(:admin) { create(:user, club: club, role: 'admin') }

  before do
    create(:sede, club: club)
    sign_in_as(admin)
  end

  it 'POST /usuarios ya no crea a nadie, ni por la API' do
    expect {
      post '/usuarios', params: { user: { email: 'nuevo@test.com', first_name: 'N', last_name: 'N', role: 'cultivador' } },
                        headers: auth_headers
    }.not_to change(User, :count)
    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)['errors'].join).to include('Pedir un usuario')
  end

  describe 'pedir un usuario' do
    def pedir(params)
      post '/usuarios/pedido', params: params, headers: auth_headers, as: :json
    end

    it 'deja el pedido en la bandeja de super admin, con la organización, la persona y el rol' do
      expect { pedir(nombre: 'Ana', apellido: 'Pérez', email: 'ana@gmail.com', rol: 'dispensador', nota: 'turno tarde') }
        .to change(SolicitudContacto.where(tipo: 'usuario'), :count).by(1)
      expect(response).to have_http_status(:created)

      s = SolicitudContacto.last
      expect(s.organizacion).to eq(club.name)
      expect(s.mensaje).to include('Ana Pérez', 'ana@gmail.com', 'Dispensador', 'turno tarde')
      expect(User.where(email: 'ana@gmail.com')).to be_empty # pedir no crea a nadie
    end

    it 'avisa en el pedido si pasaría el cupo del plan' do
      2.times { |i| create(:user, club: club, role: 'dispensador', email: "d#{i}@test.com") }
      pedir(nombre: 'Tercera', rol: 'dispensador')

      expect(SolicitudContacto.last.mensaje).to include('PASA EL CUPO')
    end

    it 'sin nombre o con un rol que la organización no puede tener, no se pide' do
      pedir(nombre: '', rol: 'cultivador')
      expect(response).to have_http_status(:unprocessable_entity)
      pedir(nombre: 'X', rol: 'super_admin')
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'sólo lo hace el admin' do
      sign_in_as(create(:user, :cultivador, club: club))
      pedir(nombre: 'X', rol: 'cultivador')
      expect(response).to have_http_status(:forbidden)
    end
  end
end
