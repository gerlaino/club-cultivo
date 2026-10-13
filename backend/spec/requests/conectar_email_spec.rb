require 'rails_helper'

RSpec.describe 'PATCH /preferences/conectar_email', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, name: 'Mi Club') }
  let(:admin) { create(:user, :admin, club: club, email: 'admin@miclub.com') }

  before do
    # El servidor se valida contra el DNS (`Seguridad::DestinoPublico`): los specs no dependen
    # de la red de la máquina que los corre.
    allow(Seguridad::DestinoPublico).to receive(:direcciones).and_call_original
    allow(Seguridad::DestinoPublico).to receive(:direcciones).with('smtp.gmail.com').and_return(%w[142.250.0.108])
    allow(Seguridad::DestinoPublico).to receive(:direcciones).with('mail.interno.example').and_return(%w[10.0.0.9])
    sign_in_as(admin)
  end

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

  # Barrido de seguridad, 13-oct-2026: el servidor se conectaba a cualquier host y puerto, y el
  # error crudo de la conexión decía qué había del otro lado.
  it 'no se conecta a un servidor de la red interna' do
    ['10.0.0.5', '127.0.0.1', '169.254.169.254', 'mail.interno.example'].each do |host|
      patch '/preferences/conectar_email',
            params: { email: 'yo@miempresa.com', app_password: 'x', smtp_host: host, smtp_port: 587 },
            headers: auth_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity), "aceptó #{host}"
    end
    expect(club.reload.smtp_host).to be_nil
  end

  it 'sólo acepta puertos de correo' do
    patch '/preferences/conectar_email',
          params: { email: 'miclub@gmail.com', app_password: 'x', smtp_port: 6379 },
          headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(club.reload.smtp_host).to be_nil
  end

  it 'el SMTP no se carga por el PUT general de preferencias (sólo por conectar, que valida)' do
    patch '/preferences', params: { club: { smtp_host: '10.0.0.5', smtp_port: 6379, smtp_pass: 'x' } },
          headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(club.reload.smtp_host).to be_nil
  end

  it 'el mail de prueba usa el remitente del club (no rompe con @club nil en el bloque)' do
    club.update!(smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'miclub@gmail.com', smtp_pass: 'p',
                 smtp_from: 'miclub@gmail.com', smtp_from_name: 'Mi Club')
    post '/preferences/test_smtp', headers: auth_headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(ActionMailer::Base.deliveries.last.from).to include('miclub@gmail.com')
  end
end
