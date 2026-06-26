require 'rails_helper'

RSpec.describe 'PATCH /preferences/conectar_email', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, name: 'Mi Club') }
  let(:admin) { create(:user, :admin, club: club, email: 'admin@miclub.com') }

  before { sign_in_as(admin) }

  it 'conecta la casilla del club autodetectando el servidor (Gmail) y queda en modo propio' do
    patch '/preferences/conectar_email',
          params: { email: 'miclub@gmail.com', app_password: 'abcd efgh ijkl mnop', from_name: 'Mi Club' },
          headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['email_modo']).to eq('propio')
    expect(body['smtp_configured']).to be true

    club.reload
    expect(club.smtp_host).to eq('smtp.gmail.com')
    expect(club.smtp_port).to eq(587)
    expect(club.smtp_user).to eq('miclub@gmail.com')
    expect(club.smtp_from).to eq('miclub@gmail.com')
  end

  it 'desconectar deja el correo sin configurar' do
    club.update!(smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'x@gmail.com', smtp_pass: 'p',
                 smtp_from: 'x@gmail.com', smtp_from_name: 'X')
    delete '/preferences/desconectar_email', headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['email_modo']).to eq('sin_configurar')
    expect(club.reload.smtp_configured?).to be false
  end

  it 'pide email y contraseña' do
    patch '/preferences/conectar_email', params: { email: '' }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
