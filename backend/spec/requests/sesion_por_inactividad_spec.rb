require 'rails_helper'

# AC (Germán, 4-oct-2026): la sesión no vence a las 12 horas fijas del login; dura mientras se use
# y vence a los 7 días SIN USO. Cada pedido con un token de más de una hora devuelve uno nuevo.
RSpec.describe 'Sesión por inactividad', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def payload(bearer) = Warden::JWTAuth::TokenDecoder.new.call(bearer.sub('Bearer ', ''))

  it 'el token del login vale 7 días' do
    token = mobile_login_as(admin)
    p = payload(token)
    expect(p['exp'] - p['iat']).to eq(7.days.to_i)
  end

  it 'con un token de hace más de una hora, la respuesta trae uno nuevo' do
    token = travel_to(2.hours.ago) { mobile_login_as(admin) }
    get '/api/me', headers: { 'Authorization' => token, 'X-Mobile-Client' => 'true' }
    expect(response).to have_http_status(:ok)
    nuevo = response.headers['Authorization']
    expect(nuevo).to be_present
    expect(payload(nuevo)['exp']).to be > payload(token)['exp']
  end

  it 'con un token reciente no se renueva (no se firma uno por pedido)' do
    token = mobile_login_as(admin)
    get '/api/me', headers: { 'Authorization' => token, 'X-Mobile-Client' => 'true' }
    expect(response.headers['Authorization']).to be_nil
  end

  it 'en la web la renovación llega como cookie de 7 días' do
    sign_in_as(admin)
    travel 2.hours do
      get '/api/me'
      cookie = Array(response.headers['Set-Cookie']).join("\n")
      expect(cookie).to include('jwt_token=')
      expires = Time.httpdate(cookie[/expires=([^;]+)/i, 1])
      expect(expires).to be_within(1.minute).of(7.days.from_now)
    end
  end

  it 'pasados 7 días sin uso, el token ya no entra' do
    token = mobile_login_as(admin)
    reset! # sólo el token: sin la cookie de sesión de Rails que el login también deja
    travel(7.days + 1.minute) do
      get '/api/me', headers: { 'Authorization' => token, 'X-Mobile-Client' => 'true' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # El bug del 25-sep: `JwtDenylist.jwt_revoked?` llamaba a un `super` que no existe y todo pedido
  # autenticado SÓLO con el token (sin la cookie de sesión de Rails) reventaba.
  it 'un pedido con sólo el token (sin la sesión de Rails) entra' do
    token = mobile_login_as(admin)
    reset!
    get '/api/me', headers: { 'Authorization' => token, 'X-Mobile-Client' => 'true' }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['email']).to eq(admin.email)
  end

  it 'un token cerrado con logout ya no entra' do
    token = mobile_login_as(admin)
    delete '/api/users/sign_out', headers: { 'Authorization' => token, 'X-Mobile-Client' => 'true' }
    reset!
    get '/api/me', headers: { 'Authorization' => token, 'X-Mobile-Client' => 'true' }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'cambiar la contraseña deja afuera los tokens viejos' do
    token = mobile_login_as(admin)
    admin.update!(password: 'otra-clave-123', password_confirmation: 'otra-clave-123')
    reset!
    get '/api/me', headers: { 'Authorization' => token, 'X-Mobile-Client' => 'true' }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'un token cerrado (logout) no se olvida hasta que vence solo' do
    JwtDenylist.create!(jti: 'a', exp: 3.days.from_now)
    JwtDenylist.create!(jti: 'b', exp: 1.minute.ago)
    expect(JwtDenylist.expired.pluck(:jti)).to eq(['b'])
  end
end
