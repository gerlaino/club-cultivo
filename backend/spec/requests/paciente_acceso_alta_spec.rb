require 'rails_helper'

# AC: dar de alta un paciente le crea la cuenta con la que entra a su portal, y quien lo dio de
# alta ve las credenciales para pasárselas.
#
# La cuenta nace cuando el paciente queda ADMITIDO, igual que el mail de bienvenida: una
# solicitud cargada en el mostrador que nadie aprobó todavía no es paciente de la organización.
RSpec.describe 'La cuenta del paciente', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, name: 'Mi Organización', vista_paciente_activa: true,
                  features: { 'cultivo' => true, 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin) { create(:user, :admin, club: club) }

  def alta!(nombre: 'Ana', apellido: 'Díaz', dni: '30111222')
    post '/api/pacientes', params: {
      paciente: { nombre: nombre, apellido: apellido, dni: dni, fecha_nacimiento: '1990-05-05' }
    }, as: :json
  end

  describe 'cuando la da de alta el admin' do
    before { sign_in_as(admin) }

    it 'crea la cuenta y devuelve las credenciales para dárselas en mano' do
      alta!

      expect(response).to have_http_status(:created), response.body
      acceso = JSON.parse(response.body)['acceso']
      expect(acceso['email']).to eq('ana.diaz@mi-organizacion.paciente')
      expect(acceso['password_inicial']).to be_present
    end

    it 'la cuenta entra: es del paciente, en su organización' do
      alta!

      acceso = JSON.parse(response.body)['acceso']
      user = User.find_by(email: acceso['email'])
      expect(user.role).to eq('paciente')
      expect(user.club_id).to eq(club.id)
      expect(user.valid_password?(acceso['password_inicial'])).to be true
    end
  end

  # Sin el módulo no hay portal a donde entrar: crear la cuenta sería dejar tirado un usuario que
  # no puede loguearse (`check_rol_habilitado!` lo frena) y que igual ocupa un mail.
  describe 'sin el módulo contratado' do
    let(:club) { create(:club, features: { 'produccion_dispensa' => true }) }

    before { sign_in_as(admin) }

    it 'no crea ninguna cuenta' do
      expect { alta! }.not_to change(User, :count)
      expect(JSON.parse(response.body)['acceso']).to be_nil
    end
  end

  describe 'cuando la carga el mostrador' do
    let(:dispensador) { create(:user, :dispensador, club: club) }

    it 'no crea la cuenta hasta que alguien la apruebe' do
      sign_in_as(dispensador)

      expect { alta! }.not_to change(User, :count)
      expect(JSON.parse(response.body)['acceso']).to be_nil
    end

    it 'al aprobarla, la cuenta nace y el admin ve las credenciales' do
      sign_in_as(dispensador)
      alta!
      paciente_id = JSON.parse(response.body)['data']['id']

      sign_in_as(admin)
      post "/api/pacientes/#{paciente_id}/aprobar", as: :json

      expect(response).to have_http_status(:ok), response.body
      acceso = JSON.parse(response.body)['acceso']
      expect(acceso['email']).to eq('ana.diaz@mi-organizacion.paciente')
      expect(acceso['password_inicial']).to be_present
    end
  end
end

# AC: el acceso al portal se corta desactivando al paciente en su ficha. Es el mismo interruptor
# que ya le impide dispensar y reservar — la organización no tiene que acordarse de ir a borrarle
# el usuario por otro lado, porque nadie se acuerda.
RSpec.describe 'La baja del acceso del paciente', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, vista_paciente_activa: true,
                  features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:paciente) { ActsAsTenant.with_tenant(club) { create(:paciente, club: club) } }
  # La cuenta real que crea el alta, con la clave del helper para poder loguearla: la que genera
  # el servicio es al azar a propósito.
  let(:cuenta) do
    ActsAsTenant.with_tenant(club) do
      user = Pacientes::Acceso.crear!(paciente).user
      user.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
      user
    end
  end

  def entrar = get '/api/portal/geneticas'

  it 'mientras está activo, entra' do
    sign_in_as(cuenta)
    entrar

    expect(response).to have_http_status(:ok), response.body
  end

  it 'desactivado en la ficha, deja de entrar y se le explica' do
    sign_in_as(cuenta)
    paciente.update_column(:es_paciente, false)

    entrar

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)['error']).to include('dada de baja')
  end

  it 'borrada la ficha, tampoco' do
    sign_in_as(cuenta)
    paciente.update_column(:deleted_at, Time.current)

    entrar

    expect(response).to have_http_status(:forbidden)
  end

  it 'reactivado, vuelve a entrar sin que nadie le toque la cuenta' do
    sign_in_as(cuenta)
    paciente.update_column(:es_paciente, false)
    entrar
    expect(response).to have_http_status(:forbidden)

    paciente.update_column(:es_paciente, true)
    entrar

    expect(response).to have_http_status(:ok), response.body
  end
end
