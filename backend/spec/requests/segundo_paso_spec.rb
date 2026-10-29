require 'rails_helper'

# AC (29-oct-2026, seguridad tanda 2, AUTH-2FA; Germán: «sí»): el super admin entra con mail, clave
# Y el código de seis números de su app. Sin código no hay sesión. Hasta activarlo no opera: sólo
# se ve a sí mismo, lo activa (con su clave y un código) y sale. El resto de los roles no cambia.
RSpec.describe 'Segundo paso al entrar', type: :request do
  include ActiveJob::TestHelper

  let(:clave) { AuthHelpers::DEFAULT_PASSWORD }

  def entrar(user, codigo: nil, movil: false)
    post '/api/users/sign_in', params: { user: { email: user.email, password: clave, codigo: codigo }.compact },
                               headers: movil ? { 'X-Mobile-Client' => 'true' } : {}, as: :json
  end

  def codigo_de(user, paso: Seguridad::Totp.paso_de)
    Seguridad::Totp.codigo(user.reload.otp_secret, paso)
  end

  describe 'con el segundo paso activo' do
    let(:super_admin) { create(:user, :super_admin) }

    it 'sin código no entra: 401, pide el código y no sale cookie ni token' do
      entrar(super_admin)

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include('necesita_codigo' => true)
      expect(response.headers['Authorization']).to be_blank
      expect(response.headers['Set-Cookie'].to_s).not_to include('jwt_token=')
      get '/api/super_admin/clubs', as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'tampoco por la app del teléfono (no sale el Bearer)' do
      entrar(super_admin, movil: true)

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['Authorization']).to be_blank
    end

    it 'con un código equivocado no entra' do
      entrar(super_admin, codigo: '000000')

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['error']).to include('no es correcto')
    end

    it 'con la clave equivocada no llega a pedir el código' do
      post '/api/users/sign_in', params: { user: { email: super_admin.email, password: 'otra' } }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).not_to include('necesita_codigo')
    end

    it 'con el código de ahora entra y opera' do
      entrar(super_admin, codigo: codigo_de(super_admin))

      expect(response).to have_http_status(:ok)
      get '/api/super_admin/clubs', as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'el mismo código no sirve dos veces' do
      codigo = codigo_de(super_admin)
      entrar(super_admin, codigo: codigo)
      expect(response).to have_http_status(:ok)

      reset!
      entrar(super_admin, codigo: codigo)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'con la salida de emergencia (SEGUNDO_PASO_SUPER_ADMIN=apagado) entra sin código' do
      ENV['SEGUNDO_PASO_SUPER_ADMIN'] = 'apagado'
      entrar(super_admin)
      expect(response).to have_http_status(:ok)
    ensure
      ENV.delete('SEGUNDO_PASO_SUPER_ADMIN')
    end
  end

  describe 'super admin que todavía no lo activó' do
    let(:super_admin) { create(:user, :super_admin, segundo_paso: false) }

    before do
      entrar(super_admin)
      expect(response).to have_http_status(:ok)
    end

    it 'entra con mail y clave, pero no opera: 403 con segundo_paso_pendiente' do
      get '/api/super_admin/clubs', as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to include('segundo_paso_pendiente' => true)
    end

    it '/me le dice que está pendiente (la app lo lleva a activarlo)' do
      get '/api/me', as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['segundo_paso_pendiente'] || response.parsed_body.dig('data', 'segundo_paso_pendiente')).to be(true)
    end

    it 'empezar pide la contraseña' do
      post '/api/profile/segundo_paso/iniciar', params: { user: { current_password: 'no-es' } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(super_admin.reload.otp_secret).to be_blank
    end

    it 'lo activa: QR, código de la app, y desde ahí opera; llega un mail avisando' do
      post '/api/profile/segundo_paso/iniciar', params: { user: { current_password: clave } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['uri']).to start_with('otpauth://totp/')
      secreto = response.parsed_body['secreto']
      expect(super_admin.reload.segundo_paso_activo?).to be(false)

      post '/api/profile/segundo_paso/activar', params: { codigo: '123456' }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      perform_enqueued_jobs do
        post '/api/profile/segundo_paso/activar', params: { codigo: Seguridad::Totp.codigo(secreto, Seguridad::Totp.paso_de) }, as: :json
      end
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['activo']).to be(true)

      get '/api/super_admin/clubs', as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'ya activo, no se puede volver a empezar desde la app (sólo por consola)' do
      super_admin.update!(otp_secret: Seguridad::Totp.generar_secreto, otp_activado_at: Time.current)
      post '/api/profile/segundo_paso/iniciar', params: { user: { current_password: clave } }, as: :json
      expect(response).to have_http_status(:conflict)
    end
  end

  describe 'los demás roles' do
    let(:club)  { create(:club) }
    let(:admin) { create(:user, :admin, club: club) }

    it 'entran como siempre, sin código' do
      entrar(admin)
      expect(response).to have_http_status(:ok)
      get '/api/me', as: :json
      expect(response.parsed_body.to_s).not_to include('segundo_paso_pendiente')
    end

    it 'no pueden activarlo (por ahora es del super admin)' do
      entrar(admin)
      post '/api/profile/segundo_paso/iniciar', params: { user: { current_password: clave } }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
