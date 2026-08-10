require 'rails_helper'

# Un cultivador en un club que apagó la suite Cultivo entraba igual y después cada endpoint
# suyo le devolvía 403 sin decir por qué: parecía la app rota. Ahora el rechazo llega una vez,
# en el login, y nombra el módulo que falta.
RSpec.describe 'Rol cuyo módulo está apagado', type: :request do
  def club_sin(*claves)
    features = Club::FEATURES_POR_DEFECTO.dup
    claves.each { |c| features[c.to_s] = false }
    create(:club, features: features)
  end

  def intentar_login(user)
    post '/api/users/sign_in',
         params: { user: { email: user.email, password: 'password123' } },
         as: :json
  end

  describe 'login' do
    it 'rechaza al cultivador con el motivo cuando el club apagó Cultivo' do
      club = club_sin(:cultivo)
      user = create(:user, :cultivador, club: club)

      intentar_login(user)

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body['modulo_rol_apagado']).to be(true)
      expect(body['error']).to include('Cultivo')
      expect(body['error']).to include('administrador')
    end

    # El dispensador atiende dispensa Y mostrador del Buffet: se lo frena sólo cuando no le
    # queda ninguno de los dos.
    it 'deja entrar al dispensador de un club que sólo tiene el Buffet' do
      club = club_sin(:produccion_dispensa)
      user = create(:user, :dispensador, club: club)

      intentar_login(user)

      expect(response).to have_http_status(:ok)
    end

    it 'rechaza al dispensador cuando no le queda ni dispensa ni Buffet' do
      club = club_sin(:produccion_dispensa, :bar)
      user = create(:user, :dispensador, club: club)

      intentar_login(user)

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']).to include('Producción y dispensa')
    end

    # El módulo médico viene DENTRO de la suite de Producción y dispensa, así que al médico lo
    # deja afuera perder la suite, no un interruptor propio que ya no existe.
    it 'rechaza al médico cuando el club no tiene la suite que incluye su módulo' do
      club = club_sin(:produccion_dispensa)
      user = create(:user, :medico, club: club)

      intentar_login(user)

      expect(response).to have_http_status(:forbidden)
    end

    it 'deja entrar al supervisor si le queda UNA de las dos suites' do
      club = club_sin(:cultivo)
      user = create(:user, :supervisor, club: club)

      intentar_login(user)

      expect(response).to have_http_status(:ok)
    end

    it 'rechaza al supervisor sólo cuando se apagan las DOS suites' do
      club = club_sin(:cultivo, :produccion_dispensa)
      user = create(:user, :supervisor, club: club)

      intentar_login(user)

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['error']).to include('Cultivo o Producción y dispensa')
    end

    # Los roles transversales tienen que poder mirar el histórico de un módulo dado de baja.
    %i[admin auditor abogado].each do |rol|
      it "deja entrar al #{rol} aunque el club no tenga ninguna suite" do
        club = club_sin(:cultivo, :produccion_dispensa, :medico)
        user = create(:user, rol, club: club)

        intentar_login(user)

        expect(response).to have_http_status(:ok)
      end
    end

    it 'no bloquea a nadie cuando el club tiene todo prendido' do
      club = create(:club)
      user = create(:user, :cultivador, club: club)

      intentar_login(user)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'sesión ya abierta cuando el admin apaga la suite' do
    let(:club) { create(:club) }

    it 'corta con el mismo motivo en vez de dejarlo con pantallas vacías' do
      user = create(:user, :cultivador, club: club)
      sign_in_as(user)

      get '/api/lotes'
      expect(response).to have_http_status(:ok)

      club.update!(features: club.features.merge('cultivo' => false))

      get '/api/lotes'
      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body['modulo_rol_apagado']).to be(true)
      expect(body['error']).to include('Cultivo')
    end

    it 'no le corta la sesión al admin del mismo club' do
      admin = create(:user, :admin, club: club)
      sign_in_as(admin)
      club.update!(features: club.features.merge('cultivo' => false))

      get '/api/pacientes'
      expect(response).to have_http_status(:ok)
    end
  end
end
