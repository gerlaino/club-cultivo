require 'rails_helper'

# AC: la contraseña le llega al paciente por mail, desde la casilla de la organización.
#
# Mostrarla una sola vez en pantalla obliga a quien la creó a anotarla y hacérsela llegar por su
# cuenta; con veinte pacientes eso no pasa. La pantalla la sigue mostrando igual, que es la única
# salida cuando el paciente no tiene mail o la organización no tiene casilla.
RSpec.describe 'La contraseña del paciente, por mail', type: :request do
  include AuthHelpers

  let(:club) do
    create(:club, name: 'Mi Organización', vista_paciente_activa: true,
                  features: { 'produccion_dispensa' => true, 'vista_paciente' => true, 'mailer' => true },
                  smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'club@gmail.com',
                  smtp_pass: 'x', smtp_from: 'club@gmail.com')
  end
  let(:admin) { create(:user, :admin, club: club) }
  let(:paciente) do
    ActsAsTenant.with_tenant(club) do
      create(:paciente, club: club, nombre: 'Ana', apellido: 'Díaz', email: 'ana@example.com', created_by: admin)
    end
  end

  before { sign_in_as(admin) }

  it 'se le manda al crearle la cuenta, y la respuesta lo dice' do
    expect { post "/api/pacientes/#{paciente.id}/acceso" }
      .to change { ActionMailer::Base.deliveries.size }.by(1)

    expect(JSON.parse(response.body)['credenciales']['mail_enviado']).to be(true)
  end

  it 'el mail lleva el usuario y la contraseña, que es todo lo que necesita' do
    post "/api/pacientes/#{paciente.id}/acceso"

    clave = JSON.parse(response.body)['credenciales']['password_inicial']
    mail  = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(['ana@example.com'])
    expect(mail.body.encoded).to include(clave)
    expect(mail.body.encoded).to include('ana.diaz@mi-organizacion.paciente')
  end

  # Un mail por destinatario, siempre: nunca un `To:` con varias direcciones.
  it 'va a UNA sola dirección' do
    post "/api/pacientes/#{paciente.id}/acceso"

    expect(ActionMailer::Base.deliveries.last.to.size).to eq(1)
  end

  # Guardarla en claro en `mails_enviados.cuerpo` sería peor que no mandar nada: queda en la base
  # para siempre y la ve cualquiera con acceso al historial del paciente.
  it 'el historial registra que se le mandó, pero NO la contraseña' do
    post "/api/pacientes/#{paciente.id}/acceso"

    clave    = JSON.parse(response.body)['credenciales']['password_inicial']
    registro = MailEnviado.where(paciente_id: paciente.id).last
    expect(registro.tipo).to eq('acceso_portal')
    expect(registro.cuerpo).not_to include(clave)
  end

  it 'al restablecer también, y el mail avisa que la anterior dejó de servir' do
    post "/api/pacientes/#{paciente.id}/acceso"
    ActionMailer::Base.deliveries.clear

    post "/api/pacientes/#{paciente.id}/acceso/restablecer"

    expect(ActionMailer::Base.deliveries.size).to eq(1)
    # Sin tildes: el cuerpo viaja en quoted-printable y los acentos salen escapados.
    expect(ActionMailer::Base.deliveries.last.body.encoded).to include('La anterior')
  end

  describe 'cuando no se puede mandar' do
    it 'sin mail del paciente: la cuenta se crea igual y la respuesta lo dice' do
      paciente.update_column(:email, nil)

      expect { post "/api/pacientes/#{paciente.id}/acceso" }
        .not_to change { ActionMailer::Base.deliveries.size }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['credenciales']['mail_enviado']).to be(false)
    end

    it 'sin el módulo de correo tampoco, y la cuenta se crea igual' do
      club.update!(features: club.features.merge('mailer' => false))

      expect { post "/api/pacientes/#{paciente.id}/acceso" }
        .not_to change { ActionMailer::Base.deliveries.size }

      expect(response).to have_http_status(:created)
    end

    # Que la pantalla lo diga ANTES de crear la cuenta, no después: para entonces quien la creó ya
    # cerró el cartel con la única copia de la contraseña.
    it 'la ficha avisa de antemano qué falta' do
      paciente.update_column(:email, nil)

      get "/api/pacientes/#{paciente.id}"

      acceso = JSON.parse(response.body)['data']['acceso']
      expect(acceso['mail_posible']).to be(false)
      expect(acceso['mail_falta']).to include('no tiene mail')
    end
  end
end
