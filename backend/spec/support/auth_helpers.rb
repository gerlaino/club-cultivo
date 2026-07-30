module AuthHelpers
  DEFAULT_PASSWORD = 'password123'.freeze

  # Autentica via cookie httpOnly. Rails request specs persisten las cookies
  # entre requests dentro del mismo example, así que no hay que pasar headers
  # manualmente — el cookie jar del test envía jwt_token automáticamente.
  def sign_in_as(user, password: DEFAULT_PASSWORD)
    # Limpiar la cookie ANTES de loguear. Sin esto, un segundo sign_in_as en el mismo example no
    # cambiaba de usuario: la cookie vieja seguía ganando y el spec terminaba probando al usuario
    # anterior. Es un falso VERDE silencioso —un caso de "el rol X no puede hacer Y" pasaba porque
    # en realidad seguía actuando el admin— así que vale para toda la suite, no para un spec.
    reset!   # nuevo cookie jar: cookies.delete no alcanza con la cookie httpOnly de Devise JWT
    post '/api/users/sign_in', params: { user: { email: user.email, password: password } }, as: :json
    expect(response).to have_http_status(:ok), "sign_in_as falló para #{user.email}: #{response.body}"
    # Con require_tenant=true (TEN-01c), el setup de fixtures y las aserciones posteriores al
    # login necesitan un tenant. Usamos test_tenant (no current_tenant) para que sobreviva a
    # los requests siguientes vía el TestTenantMiddleware. Cubre specs sin let(:club). Los
    # specs cross-tenant que crean datos de OTRO club los envuelven en with_tenant(otro_club).
    ActsAsTenant.test_tenant = user.club
  end

  # Mantenido por compatibilidad con specs existentes que pasan headers: auth_headers.
  # Ya no contiene el Authorization header — la cookie viaja automáticamente.
  def auth_headers
    {}
  end

  # Variante mobile: devuelve el Bearer token del Authorization response header.
  def mobile_login_as(user, password: DEFAULT_PASSWORD)
    post '/api/users/sign_in',
         params:  { user: { email: user.email, password: password } },
         headers: { 'X-Mobile-Client' => 'true' },
         as: :json
    expect(response).to have_http_status(:ok)
    response.headers['Authorization'] # "Bearer <jwt>"
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
