require 'rails_helper'

# AC: la cuenta del portal se puede VER y gestionar desde la ficha del paciente.
#
# Sin esto la contraseña inicial se mostraba una vez al dar el alta y después no había ningún
# lugar donde ver siquiera cuál era el usuario. Y los pacientes cargados antes de que existiera el
# portal no tenían cuenta ni forma de conseguirla.
RSpec.describe 'La cuenta del portal, desde la ficha', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, name: 'Mi Organización', vista_paciente_activa: true,
                  features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin)    { create(:user, :admin, club: club) }
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club, nombre: 'Ana', apellido: 'Díaz', created_by: admin) } }

  def ficha = get "/api/pacientes/#{paciente.id}"
  def acceso_de_la_ficha = JSON.parse(response.body)['data']['acceso']

  describe 'un paciente que todavía no tiene cuenta' do
    before { sign_in_as(admin) }

    it 'la ficha lo dice, y muestra qué usuario le quedaría' do
      ficha

      expect(acceso_de_la_ficha['tiene']).to be(false)
      expect(acceso_de_la_ficha['sugerido']).to eq('ana.diaz@mi-organizacion.paciente')
    end

    it 'se le puede crear desde ahí, y devuelve las credenciales para pasárselas' do
      post "/api/pacientes/#{paciente.id}/acceso"

      expect(response).to have_http_status(:created), response.body
      body = JSON.parse(response.body)
      expect(body['credenciales']['email']).to eq('ana.diaz@mi-organizacion.paciente')
      expect(body['credenciales']['password_inicial']).to be_present
      expect(body['data']['tiene']).to be(true)
    end

    it 'crearla dos veces no le rota la clave a quien ya la tenía anotada' do
      post "/api/pacientes/#{paciente.id}/acceso"
      post "/api/pacientes/#{paciente.id}/acceso"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].first).to include('Restablecer')
    end
  end

  describe 'un paciente que ya tiene cuenta' do
    before do
      sign_in_as(admin)
      post "/api/pacientes/#{paciente.id}/acceso"
    end

    it 'la ficha muestra su usuario: sin esto no había dónde consultarlo' do
      ficha

      expect(acceso_de_la_ficha['tiene']).to be(true)
      expect(acceso_de_la_ficha['email']).to eq('ana.diaz@mi-organizacion.paciente')
      expect(acceso_de_la_ficha['activo']).to be(true)
    end

    it 'se le puede dar una contraseña nueva, y la vieja deja de servir' do
      vieja = JSON.parse(response.body)['credenciales']['password_inicial']

      post "/api/pacientes/#{paciente.id}/acceso/restablecer"

      expect(response).to have_http_status(:ok), response.body
      nueva = JSON.parse(response.body)['credenciales']['password_inicial']
      expect(nueva).not_to eq(vieja)

      user = paciente.reload.user
      expect(user.valid_password?(nueva)).to be(true)
      expect(user.valid_password?(vieja)).to be(false)
    end

    it 'desactivado el paciente, la ficha avisa que la cuenta no entra' do
      paciente.update_column(:es_paciente, false)
      ficha

      expect(acceso_de_la_ficha['tiene']).to be(true)
      expect(acceso_de_la_ficha['activo']).to be(false)
    end
  end

  # El mostrador carga solicitudes pero no reparte accesos: es la misma línea que ya separa cargar
  # un alta de aprobarla.
  describe 'quién puede gestionarla' do
    it 'el dispensador no' do
      sign_in_as(create(:user, :dispensador, club: club))

      post "/api/pacientes/#{paciente.id}/acceso"

      expect(response).to have_http_status(:forbidden)
    end

    it 'y la ficha se lo dice, para no ofrecerle un botón que rebota' do
      sign_in_as(create(:user, :dispensador, club: club))
      ficha

      expect(acceso_de_la_ficha['puede_gestionar']).to be(false)
    end
  end

  describe 'sin el módulo contratado' do
    let(:club) { create(:club, features: { 'produccion_dispensa' => true }) }

    before { sign_in_as(admin) }

    it 'la ficha no habla de cuentas' do
      ficha

      expect(acceso_de_la_ficha['modulo']).to be(false)
    end

    it 'y no se puede crear ninguna' do
      post "/api/pacientes/#{paciente.id}/acceso"

      expect(response).to have_http_status(:forbidden)
    end
  end
end
