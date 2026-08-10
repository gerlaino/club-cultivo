require 'rails_helper'

# AC: un super_admin que NO está observando ninguna organización y cae en un endpoint de
# organización recibe un mensaje que se entiende, no un 500.
#
# El bug: el super_admin es el único rol sin club. `current_user.club` es nil y el tenant queda
# sin fijar, así que cualquiera de los ~180 `current_user.club.algo` que hay en los controllers
# explota con NoMethodError, y los que no, revientan con NoTenantSet (require_tenant=true).
RSpec.describe 'Super admin sin organización en contexto', type: :request do
  let(:super_admin) { create(:user, :super_admin, club: nil) }
  let(:club)        { create(:club) }

  before { sign_in_as(super_admin) }

  describe 'endpoints de organización' do
    # Los tres caminos por los que se llegaba al 500: listar, ver el detalle y escribir.
    it 'contesta 409 y explica qué falta, en vez de reventar' do
      get '/api/pacientes'

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body['sin_contexto_de_club']).to be(true)
      expect(body['error']).to include('panel de plataforma')
    end

    it 'también en cultivo' do
      get '/api/lotes'
      expect(response).to have_http_status(:conflict)
    end

    it 'también al intentar escribir' do
      post '/api/pacientes', params: { paciente: { nombre: 'X', apellido: 'Y', dni: '12345678',
                                                   fecha_nacimiento: '1990-01-01' } }
      expect(response).to have_http_status(:conflict)
      # Lo importante: NO se creó nada suelto sin club.
      expect(ActsAsTenant.without_tenant { Paciente.unscoped.count }).to eq(0)
    end
  end

  describe 'lo que el super admin sí usa' do
    it 'el panel de plataforma sigue andando' do
      get '/api/super_admin/clubs'
      expect(response).to have_http_status(:ok)
    end

    it '/me sigue andando (con esto arranca la app)' do
      get '/api/me'
      expect(response).to have_http_status(:ok)
    end

    it 'su propio perfil sigue andando' do
      get '/api/profile'
      expect(response).to have_http_status(:ok)
    end

    it 'puede cerrar sesión' do
      delete '/api/users/sign_out'
      expect(response.status).to be_between(200, 299)
    end
  end

  describe 'observando una organización' do
    it 'no se bloquea: ahí sí hay tenant' do
      skip 'modo observador suspendido — ver User::OBSERVADOR_HABILITADO' unless User::OBSERVADOR_HABILITADO

      post "/api/super_admin/clubs/#{club.id}/observar"
      get '/api/pacientes'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'los demás roles no se ven afectados' do
    it 'un admin de club entra normalmente' do
      admin = create(:user, :admin, club: club)
      sign_in_as(admin)

      get '/api/pacientes'
      expect(response).to have_http_status(:ok)
    end
  end
end
