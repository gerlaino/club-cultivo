module AuthHelpers
  DEFAULT_PASSWORD = 'password123'.freeze

  def sign_in_as(user, password: DEFAULT_PASSWORD)
    post '/api/users/sign_in', params: { user: { email: user.email, password: password } }, as: :json
    token = response.headers['Authorization']
    @auth_headers = { 'Authorization' => token }
  end

  def auth_headers
    @auth_headers || {}
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
