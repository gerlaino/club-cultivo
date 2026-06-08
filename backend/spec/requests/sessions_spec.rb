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

    it 'limpia la cookie jwt_token en el response' do
      delete '/users/sign_out'
      # Rails marca una cookie eliminada con valor vacío o la ausencia del Set-Cookie con jwt_token
      expect(response.cookies['jwt_token']).to be_blank
    end

    it 'requests posteriores al logout con cookie limpia → 401' do
      delete '/users/sign_out'
      cookies.delete('jwt_token')
      get '/me'
      expect(response).to have_http_status(:unauthorized)
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
