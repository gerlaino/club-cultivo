require 'rails_helper'

# AC: al dar de alta a alguien del equipo sólo se aceptan los roles del arranque. Supervisor
# (suspendido para altas nuevas), abogado y auditor existen y funcionan, pero no se crean.
# Desde el 12-oct-2026 el alta es de la plataforma (super admin), con la misma regla.
RSpec.describe 'Alta de equipo — roles que se pueden dar de alta', type: :request do
  include AuthHelpers
  let(:club)        { create(:club) }
  let(:super_admin) { create(:user, :super_admin, club: nil) }

  before do
    create(:sede, club: club) # los roles operativos exigen al menos una sede
    sign_in_as(super_admin)
  end

  def crear(rol)
    post '/api/super_admin/users', params: {
      user: { club_id: club.id, email: "#{rol}-#{SecureRandom.hex(3)}@test.com", role: rol,
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
      expect(JSON.parse(response.body)['errors'].join.downcase).to include(rol)
    end
  end

  it 'rechaza un rol inventado' do
    crear('dueño_del_universo')
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rechaza super_admin y paciente: no son del equipo de una organización' do
    expect { crear('super_admin'); crear('paciente') }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
