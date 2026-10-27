require 'rails_helper'

# AC (27-oct-2026): dar de alta o aprobar a un paciente le crea la cuenta del portal y le arma el
# LINK para que entre (eligiendo él su clave con su DNI). Quien lo dio de alta ve el link para
# mandárselo por WhatsApp; nadie ve ni dicta una contraseña.
#
# La cuenta nace cuando el paciente queda ADMITIDO, igual que el mail de bienvenida: una
# solicitud cargada en el mostrador que nadie aprobó todavía no es paciente de la organización.
RSpec.describe 'La cuenta del paciente al darlo de alta', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, name: 'Mi Organización', vista_paciente_activa: true,
                  features: { 'cultivo' => true, 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin) { create(:user, :admin, club: club) }

  def alta!(nombre: 'Ana', apellido: 'Díaz', dni: '30111222', email: nil)
    post '/api/pacientes', params: {
      paciente: { nombre: nombre, apellido: apellido, dni: dni, fecha_nacimiento: '1990-05-05', email: email }.compact
    }, as: :json
  end

  def acceso = JSON.parse(response.body)['acceso']

  describe 'cuando la da de alta el admin' do
    before { sign_in_as(admin) }

    it 'devuelve el link para entrar, no una contraseña' do
      alta!

      expect(response).to have_http_status(:created), response.body
      expect(acceso['link']['url']).to match(%r{/portal/entrar/[\w-]{20,}\z})
      expect(acceso.to_s).not_to include('password')
    end

    it 'el texto para WhatsApp saluda por el nombre y lleva el link, sin datos de salud' do
      alta!

      expect(acceso['link']['texto']).to include('Hola Ana!', acceso['link']['url'])
      expect(acceso['link']['texto']).not_to include('30111222')
    end

    it 'la cuenta es del paciente, en su organización' do
      alta!

      user = Paciente.find(JSON.parse(response.body)['data']['id']).user
      expect(user.role).to eq('paciente')
      expect(user.club_id).to eq(club.id)
    end

    it 'si tiene mail, también le llega el link por mail' do
      expect { alta!(email: 'ana@example.com') }.to have_enqueued_mail(AccesoMailer, :portal_link)
      expect(acceso['link']['mail_enviado']).to be(true)
    end

    it 'sin mail, el link queda para mandarlo por WhatsApp y la respuesta lo dice' do
      expect { alta! }.not_to have_enqueued_mail
      expect(acceso['link']['mail_enviado']).to be(false)
    end
  end

  describe 'con el portal contratado pero cerrado' do
    let(:club) do
      create(:club, vista_paciente_activa: false,
                    features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
    end

    before { sign_in_as(admin) }

    it 'le crea la cuenta (para invitarlo cuando lo abran) pero no manda un link que hoy no abre' do
      expect { alta! }.to change(User, :count).by(1)
      expect(acceso).to be_nil
      expect(AccesoPortal.unscoped.count).to eq(0)
    end
  end

  # Sin el módulo no hay portal a donde entrar: crear la cuenta sería dejar tirado un usuario que
  # no puede loguearse (`check_rol_habilitado!` lo frena) y que igual ocupa un mail.
  describe 'sin el módulo contratado' do
    let(:club) { create(:club, features: { 'produccion_dispensa' => true }) }

    before { sign_in_as(admin) }

    it 'no crea ninguna cuenta' do
      expect { alta! }.not_to change(User, :count)
      expect(acceso).to be_nil
    end
  end

  describe 'cuando la carga el mostrador' do
    let(:dispensador) { create(:user, :dispensador, club: club) }

    it 'no crea la cuenta ni el link hasta que alguien la apruebe' do
      sign_in_as(dispensador)

      expect { alta! }.not_to change(User, :count)
      expect(acceso).to be_nil
    end

    it 'al aprobarla, la cuenta nace y el admin recibe el link' do
      sign_in_as(dispensador)
      alta!
      paciente_id = JSON.parse(response.body)['data']['id']

      sign_in_as(admin)
      post "/api/pacientes/#{paciente_id}/aprobar", as: :json

      expect(response).to have_http_status(:ok), response.body
      expect(acceso['link']['url']).to include('/portal/entrar/')
      expect(Paciente.find(paciente_id).user).to be_present
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
