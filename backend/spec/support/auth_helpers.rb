module AuthHelpers
  DEFAULT_PASSWORD = 'password123'.freeze

  # Autentica via cookie httpOnly. Rails request specs persisten las cookies
  # entre requests dentro del mismo example, así que no hay que pasar headers
  # manualmente — el cookie jar del test envía jwt_token automáticamente.
  def sign_in_as(user, password: DEFAULT_PASSWORD)
    post '/api/users/sign_in', params: { user: { email: user.email, password: password } }, as: :json
    expect(response).to have_http_status(:ok), "sign_in_as falló para #{user.email}: #{response.body}"
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
