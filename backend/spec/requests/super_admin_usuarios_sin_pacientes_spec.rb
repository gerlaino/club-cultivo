require 'rails_helper'

# AC: el listado de usuarios del panel de plataforma muestra EQUIPO, no pacientes.
#
# Las cuentas de portal de los pacientes son `User` —comparten tabla con el staff— así que sin el
# scope aparecen mezcladas con el equipo de cada organización. Con un padrón de 49 pacientes, el
# listado mostraba 49 filas de pacientes donde hay 6 personas trabajando, y empeora con cada club
# que carga su padrón.
#
# `User.del_equipo` ya existía y el listado de equipo del CLUB ya lo usaba: el de plataforma se
# pasó por alto. Es la misma regla en dos lados, que es de donde salen estas divergencias.
RSpec.describe 'Panel de plataforma — usuarios', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, vista_paciente_activa: true) }
  let(:sa)    { create(:user, :super_admin) }
  let!(:admin_club) { create(:user, :admin, club: club, first_name: 'Vera', last_name: 'Staff') }

  let!(:paciente) do
    ActsAsTenant.with_tenant(club) { create(:paciente, club: club, nombre: 'Pab', apellido: 'Uno') }
  end

  def listado
    sign_in_as(sa)
    get '/api/super_admin/users', headers: auth_headers
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end

  it 'no incluye la cuenta de portal de un paciente' do
    cuenta = ActsAsTenant.with_tenant(club) { Pacientes::Acceso.crear!(paciente) }
    expect(cuenta.user).to be_present, 'el setup no creó la cuenta: el test no probaría nada'

    emails = listado.map { |u| u['email'] }

    expect(emails).to include(admin_club.email)
    expect(emails).not_to include(cuenta.user.email)
  end

  it 'sigue mostrando al equipo de la organización' do
    roles = listado.map { |u| u['role'] }

    expect(roles).to include('admin')
    expect(roles).not_to include('paciente')
  end
end
