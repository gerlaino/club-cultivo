require 'rails_helper'

RSpec.describe 'Autenticación por cookie httpOnly', type: :request do
  let!(:club)  { create(:club) }
  let!(:admin) { create(:user, :admin, club: club) }

  # ─────────────────────────────────────────────────────────────
  # Login web (sin X-Mobile-Client)
  # ─────────────────────────────────────────────────────────────
  describe 'POST /users/sign_in — flujo web' do
    context 'con credenciales válidas' do
      before do
        post '/users/sign_in',
             params: { user: { email: admin.email, password: 'password123' } },
             as: :json
      end

      it 'responde 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'setea la cookie jwt_token' do
        expect(response.cookies['jwt_token']).to be_present
      end

      it 'la cookie es httpOnly' do
        # Set-Cookie devuelve un array; buscamos la entrada del jwt_token
        jwt_cookie = Array(response.headers['Set-Cookie']).find { |c| c.include?('jwt_token') }
        expect(jwt_cookie).to be_present, 'cookie jwt_token no encontrada en Set-Cookie'
        expect(jwt_cookie).to match(/HttpOnly/i)
      end

      it 'NO expone el JWT en el Authorization response header' do
        expect(response.headers['Authorization']).to be_nil
      end

      it 'NO incluye token en el body de respuesta' do
        expect(response.parsed_body).not_to have_key('token')
      end

      it 'devuelve los datos del usuario' do
        body = response.parsed_body
        expect(body['email']).to eq(admin.email)
        expect(body['role']).to  eq('admin')
      end
    end

    context 'con credenciales inválidas' do
      before do
        post '/users/sign_in',
             params: { user: { email: admin.email, password: 'wrongpassword' } },
             as: :json
      end

      it 'responde 401' do
        expect(response).to have_http_status(:unauthorized)
      end

      it 'NO setea cookie jwt_token' do
        jwt_cookie = Array(response.headers['Set-Cookie']).find { |c| c.include?('jwt_token') }
        expect(jwt_cookie).to be_nil
      end
    end

    context 'con email inexistente' do
      before do
        post '/users/sign_in',
             params: { user: { email: 'noexiste@test.com', password: 'password123' } },
             as: :json
      end

      it 'responde 401' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # Login mobile (X-Mobile-Client: true)
  # El middleware JwtCookieMiddleware deja el Authorization header intacto
  # para que la app nativa pueda leerlo.
  # ─────────────────────────────────────────────────────────────
  describe 'POST /users/sign_in — flujo mobile (X-Mobile-Client: true)' do
    before do
      post '/users/sign_in',
           params:  { user: { email: admin.email, password: 'password123' } },
           headers: { 'X-Mobile-Client' => 'true' },
           as: :json
    end

    it 'responde 200' do
      expect(response).to have_http_status(:ok)
    end

    it 'expone el JWT en el Authorization response header' do
      expect(response.headers['Authorization']).to be_present
      expect(response.headers['Authorization']).to start_with('Bearer ')
    end

    it 'NO setea cookie httpOnly (el token viaja en el header)' do
      jwt_cookie = Array(response.headers['Set-Cookie']).find { |c| c.include?('jwt_token') }
      expect(jwt_cookie).to be_nil
    end

    it 'el token del Authorization header autentica requests posteriores' do
      bearer = response.headers['Authorization']
      get '/me', headers: { 'Authorization' => bearer }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['email']).to eq(admin.email)
    end
  end

  # ─────────────────────────────────────────────────────────────
  # Autenticación via cookie en requests subsiguientes
  # ─────────────────────────────────────────────────────────────
  describe 'Autenticación via cookie en requests subsiguientes' do
    it 'GET /me autenticado con cookie → 200' do
      sign_in_as(admin)
      get '/me'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['email']).to eq(admin.email)
    end

    it 'GET /me sin autenticar → 401' do
      get '/me'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rutas protegidas sin cookie → 401' do
      get '/salas'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'el email del usuario autenticado coincide con quien hizo login' do
      sign_in_as(admin)
      get '/me'
      expect(response.parsed_body['email']).to eq(admin.email)
      expect(response.parsed_body['club_id']).to eq(admin.club_id)
    end
  end

  # ─────────────────────────────────────────────────────────────
  # Logout
  # ─────────────────────────────────────────────────────────────
  describe 'DELETE /users/sign_out — logout' do
    before { sign_in_as(admin) }

    it 'responde 204' do
      delete '/users/sign_out'
      expect(response).to have_http_status(:no_content)
    end

    it 'manda a borrar la cookie jwt_token (Set-Cookie vencida, no la mera ausencia)' do
      delete '/users/sign_out'
      expect(borra_cookie_jwt?(response)).to be(true)
    end

    it 'el MISMO token deja de valer después del logout' do
      token = cookies['jwt_token']
      delete '/users/sign_out'
      con_solo_el_token(token)
      get '/me'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # El caso que fallaba en producción (26-oct-2026): navegador reabierto. La sesión de Rails
  # (`_club_session`) murió al cerrarlo; la cookie del token (7 días) no. Devise creía que no había
  # nadie, contestaba 204 sin borrar la cookie ni revocar el token, y volver a `/` te metía de nuevo.
  describe 'DELETE /users/sign_out — navegador reabierto (sólo la cookie del token)' do
    let(:token) do
      sign_in_as(admin)
      cookies['jwt_token']
    end

    before { con_solo_el_token(token) }

    it 'la cookie sola autentica (el punto de partida es una sesión viva)' do
      get '/me'
      expect(response).to have_http_status(:ok)
    end

    it 'borra la cookie y el token queda revocado' do
      delete '/users/sign_out'
      expect(response).to have_http_status(:no_content)
      expect(borra_cookie_jwt?(response)).to be(true)

      con_solo_el_token(token)
      get '/me'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'cerrar sesión en un dispositivo NO saca a los demás' do
      otro_token = token_de_un_login_nuevo(admin)
      con_solo_el_token(token)
      delete '/users/sign_out'

      con_solo_el_token(otro_token)
      get '/me'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /users/sign_out — con un token que no se puede leer' do
    it 'igual borra la cookie y responde 204 (no se queda pegada)' do
      con_solo_el_token('esto.no.es-un-jwt')
      delete '/users/sign_out'
      expect(response).to have_http_status(:no_content)
      expect(borra_cookie_jwt?(response)).to be(true)
    end

    it 'un token firmado con otro secreto (rotado) tampoco rompe el logout' do
      ajeno = JWT.encode({ 'sub' => admin.id.to_s, 'scp' => 'user', 'jti' => SecureRandom.uuid,
                           'exp' => 1.day.from_now.to_i }, 'otro-secreto', 'HS256')
      con_solo_el_token(ajeno)
      delete '/users/sign_out'
      expect(response).to have_http_status(:no_content)
      expect(borra_cookie_jwt?(response)).to be(true)
    end
  end

  def con_solo_el_token(valor)
    reset!
    cookies['jwt_token'] = valor
  end

  def token_de_un_login_nuevo(user)
    reset!
    post '/api/users/sign_in', params: { user: { email: user.email, password: AuthHelpers::DEFAULT_PASSWORD } }, as: :json
    cookies['jwt_token']
  end

  def borra_cookie_jwt?(resp)
    Array(resp.headers['Set-Cookie']).flat_map { |c| c.split("\n") }.any? do |c|
      c.start_with?('jwt_token=;') && (c =~ /max-age=0/i || c.include?('1970'))
    end
  end

  # ─────────────────────────────────────────────────────────────
  # inject_jwt_from_cookie — ApplicationController
  # ─────────────────────────────────────────────────────────────
  describe 'inject_jwt_from_cookie' do
    it 'autenticación vía cookie funciona sin enviar Authorization header manual' do
      sign_in_as(admin)
      get '/me'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(admin.id)
    end

    it 'un cultivador autenticado ve sus propios datos via cookie' do
      cultivador = create(:user, :cultivador, club: club)
      sign_in_as(cultivador)
      get '/me'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['role']).to eq('cultivador')
    end
  end
end
