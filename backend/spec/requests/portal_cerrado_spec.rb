require 'rails_helper'

# AC: si la organización marca el portal como CERRADO, el paciente no entra.
#
# Este interruptor existía desde antes, se editaba en Configuración → Portal del paciente, se
# guardaba y viajaba en /preferences — y no lo leía NADIE. El admin lo apagaba, la pantalla decía
# "Portal cerrado · Tus pacientes no ven esta sección", y sus pacientes entraban igual. Es la peor
# forma del problema de "la misma regla en dos lugares": acá vivía en cero.
#
# Son DOS llaves y hacen falta las dos: el add-on CONTRATADO (lo prende el super admin) y el
# portal ABIERTO (lo prende la organización). La regla vive en `Club#portal_paciente_disponible?`.
RSpec.describe 'Portal cerrado por la organización', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, vista_paciente_activa: abierto,
                  features: { 'produccion_dispensa' => true, 'vista_paciente' => true })
  end
  let(:admin) { create(:user, :admin, club: club) }

  let(:paciente) do
    ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin) }
  end

  let(:cuenta) do
    ActsAsTenant.with_tenant(club) do
      u = Pacientes::Acceso.crear!(paciente).user
      u.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
      u
    end
  end

  def loguear
    post '/api/users/sign_in',
         params: { user: { email: cuenta.email, password: AuthHelpers::DEFAULT_PASSWORD } },
         as: :json
  end

  context 'con el portal cerrado' do
    let(:abierto) { false }

    # No es que le falte permiso adentro: no puede ni entrar. Igual que el repartidor cuando la
    # organización da de baja Delivery.
    it 'lo rechaza en el login, que es donde el mensaje se lee' do
      loguear

      expect(response).to have_http_status(:forbidden)
    end

    # El módulo está contratado: mandarlo a pedir lo que ya está comprado deja al admin buscando
    # un botón que no existe. Lo que tiene que hacer es ABRIRLO.
    it 'le dice que está cerrado, no que falta contratarlo' do
      loguear

      expect(JSON.parse(response.body)['error']).to include('cerrado')
      expect(JSON.parse(response.body)['error']).not_to include('no tiene activo el módulo')
    end

    it 'no le toca la puerta a los demás roles: el admin sigue entrando' do
      sign_in_as(admin)
      get '/api/preferences'

      expect(response).to have_http_status(:ok)
    end
  end

  # El caso que el login solo no cubre: el admin lo cierra al mediodía con gente adentro.
  context 'cerrado con la sesión ya abierta' do
    let(:abierto) { true }

    it 'corta el contenido del portal y también lo suyo' do
      sign_in_as(cuenta)
      club.update!(vista_paciente_activa: false)

      get '/api/portal/club'
      expect(response).to have_http_status(:forbidden)

      get '/api/portal/mi_estado'
      expect(response).to have_http_status(:forbidden)

      get '/api/portal/historial'
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'con el portal abierto' do
    let(:abierto) { true }

    it 'entra normal' do
      sign_in_as(cuenta)
      get '/api/portal/mi_estado'

      expect(response).to have_http_status(:ok)
    end
  end

  # Las dos llaves son independientes: abrir el portal no reemplaza al add-on.
  context 'abierto pero sin el add-on contratado' do
    let(:club) do
      create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true })
    end
    let(:abierto) { true }

    it 'sigue sin entrar, y el mensaje dice que falta el módulo' do
      loguear

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']).to include('Portal del paciente')
    end
  end
end
