require 'rails_helper'

# AC: al dar de alta a alguien del equipo sólo se ofrecen —y sólo se aceptan— los roles del
# arranque. Supervisor, abogado y auditor existen y funcionan, pero no se crean desde acá.
#
# Se valida en el BACKEND y no sólo en la pantalla: el endpoint acepta lo que le manden, así que
# esconder la opción del formulario no impide crear el usuario por la API.
RSpec.describe 'POST /api/club_users — roles que se pueden dar de alta', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  before do
    create(:sede, club: club) # los roles operativos exigen al menos una sede
    sign_in_as(admin)
  end

  def crear(rol)
    post '/api/usuarios', params: {
      user: { email: "#{rol}-#{SecureRandom.hex(3)}@test.com", role: rol,
              first_name: 'Test', last_name: 'Usuario' }
    }
  end

  Club::ROLES_ALTA_CLUB.each do |rol|
    it "acepta #{rol}" do
      crear(rol)
      expect(response.status).to be_between(200, 299), "#{rol} devolvió #{response.status}: #{response.body}"
    end
  end

  %w[supervisor abogado auditor].each do |rol|
    it "rechaza #{rol}, aunque venga por la API" do
      expect { crear(rol) }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to include(rol)
    end
  end

  it 'rechaza un rol inventado' do
    crear('dueño_del_universo')
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rechaza super_admin: no es un rol de club' do
    expect { crear('super_admin') }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
