require 'rails_helper'

RSpec.describe 'POST /pacientes/:id/enviar_mail', type: :request do
  include AuthHelpers

  let(:club)     { create(:club, name: 'Mi Club') }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:paciente) { create(:paciente, club: club, created_by: admin, email: 'socio@test.com') }

  before { sign_in_as(admin) }

  def conectar_correo!
    club.update!(smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'miclub@gmail.com',
                 smtp_pass: 'app-pass', smtp_from: 'miclub@gmail.com', smtp_from_name: 'Mi Club')
  end

  it 'envía el correo desde la casilla del club (sincrónico) cuando está configurado' do
    conectar_correo!
    expect {
      post "/pacientes/#{paciente.id}/enviar_mail",
           params: { mail: { asunto: 'Hola', cuerpo: 'Mensaje de prueba' } },
           headers: auth_headers, as: :json
    }.to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(response).to have_http_status(:created)
    entregado = ActionMailer::Base.deliveries.last
    expect(entregado.to).to eq(['socio@test.com'])
    expect(entregado.from).to eq(['miclub@gmail.com'])
  end

  it 'bloquea si el club no conectó su correo' do
    post "/pacientes/#{paciente.id}/enviar_mail",
         params: { mail: { asunto: 'Hola', cuerpo: 'x' } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['error']).to include('correo')
  end

  it 'bloquea si el paciente no tiene email' do
    conectar_correo!
    paciente.update_column(:email, nil)
    post "/pacientes/#{paciente.id}/enviar_mail",
         params: { mail: { asunto: 'Hola', cuerpo: 'x' } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
