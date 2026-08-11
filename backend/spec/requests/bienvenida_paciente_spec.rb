require 'rails_helper'

# El mail de bienvenida sale en un momento distinto según quién dé de alta:
#   - admin o médico: el alta YA es una admisión, así que sale en el acto;
#   - mostrador (dispensador, supervisor): el alta queda pendiente, y sale al aprobarla.
#
# Que el dispensador no vea el checkbox es UI. Lo que se verifica acá es la barrera de verdad:
# aunque mande el parámetro por la API, no dispara nada.
RSpec.describe 'Mail de bienvenida', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, name: 'Mitocondria').tap do |c|
      c.update!(smtp_host: 'smtp.gmail.com', smtp_port: 587,
                smtp_user: 'mito@gmail.com', smtp_pass: 'app-pass',
                smtp_from: 'mito@gmail.com', smtp_from_name: 'Mitocondria')
    end
  end
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }

  let(:datos) do
    { paciente: { nombre: 'Ana', apellido: 'Pérez', dni: '90000001',
                  fecha_nacimiento: '1990-05-14', email: 'ana@ejemplo.com' } }
  end

  before { PlantillaMail.sembrar!(club) }

  def alta(usuario, enviar:)
    sign_in_as(usuario)
    post '/pacientes', params: datos.merge(enviar_bienvenida: enviar), headers: auth_headers, as: :json
  end

  context 'cuando lo da de alta el admin' do
    it 'manda la bienvenida en el acto, con las variables resueltas' do
      expect { alta(admin, enviar: true) }.to change { MailEnviado.count }.by(1)

      expect(response).to have_http_status(:created)
      mail = MailEnviado.last
      expect(mail.tipo).to eq('bienvenida')
      expect(mail.email_destino).to eq('ana@ejemplo.com')
      expect(mail.asunto).to eq('Bienvenido/a a Mitocondria')
      expect(mail.cuerpo).to include('Hola Ana,')
      expect(mail.cuerpo).not_to include('{{')
      expect(mail.plantilla_mail.bienvenida).to be(true)
    end

    it 'no manda nada si no lo pidió' do
      expect { alta(admin, enviar: false) }.not_to change { MailEnviado.count }
    end
  end

  context 'cuando lo carga el mostrador' do
    it 'NO manda la bienvenida al crearlo, ni mandando el parámetro por la API' do
      expect { alta(dispensador, enviar: true) }.not_to change { MailEnviado.count }

      expect(response).to have_http_status(:created)
      expect(Paciente.last.pendiente_aprobacion?).to be(true)
    end

    it 'la manda recién cuando el admin aprueba el alta' do
      alta(dispensador, enviar: true)
      paciente = Paciente.last

      sign_in_as(admin)
      expect {
        post "/pacientes/#{paciente.id}/aprobar", params: { enviar_bienvenida: true },
             headers: auth_headers, as: :json
      }.to change { MailEnviado.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(paciente.reload.aprobado?).to be(true)
      expect(MailEnviado.last.paciente_id).to eq(paciente.id)
    end

    it 'el admin puede aprobar sin mandar mail' do
      alta(dispensador, enviar: true)

      sign_in_as(admin)
      expect {
        post "/pacientes/#{Paciente.last.id}/aprobar", headers: auth_headers, as: :json
      }.not_to change { MailEnviado.count }

      expect(response).to have_http_status(:ok)
    end
  end

  context 'cuando algo falta' do
    # El alta es la operación; el mail es un acompañamiento. Que no salga no puede deshacer
    # el alta ni devolver un error: el paciente quedó cargado.
    it 'da de alta igual si el paciente no tiene email, y lo avisa' do
      sign_in_as(admin)
      post '/pacientes',
           params: { paciente: datos[:paciente].except(:email), enviar_bienvenida: true },
           headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(Paciente.last.nombre).to eq('Ana')
      expect(MailEnviado.count).to eq(0)
      expect(JSON.parse(response.body)['aviso']).to match(/no salió/i)
    end

    it 'da de alta igual si la organización no conectó su casilla' do
      club.update!(smtp_host: nil, smtp_user: nil, smtp_pass: nil)
      sign_in_as(admin)

      expect { post '/pacientes', params: datos.merge(enviar_bienvenida: true),
                    headers: auth_headers, as: :json }.to change { Paciente.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['aviso']).to match(/casilla/i)
    end

    it 'no manda nada si la organización dio de baja el módulo de correo' do
      club.update!(features: club.features.merge('mailer' => false))

      expect { alta(admin, enviar: true) }.not_to change { MailEnviado.count }
      expect(response).to have_http_status(:created)
    end
  end
end
