require 'rails_helper'

# El mail con el link del portal (invitación o «me olvidé la clave»): sale por la casilla de la
# plataforma, al mail de la ficha, con el link y nada más. Ni el DNI ni ningún dato de salud.
RSpec.describe AccesoMailer, '#portal_link' do
  let(:club) { create(:club, name: 'Raíces', features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }
  let(:paciente) do
    ActsAsTenant.with_tenant(club) do
      create(:paciente, club: club, nombre: 'Lucía Inés', dni: '30111222', email: 'lucia@example.com',
                        aprobado_at: Time.current, diagnostico_principal: 'Insomnio crónico')
    end
  end

  def texto(mail) = mail.text_part.decoded + mail.html_part.decoded

  def mail_de(motivo)
    emitido = ActsAsTenant.with_tenant(club) { AccesoPortal.emitir!(paciente, motivo: motivo) }
    [described_class.portal_link(acceso: emitido.acceso, token: emitido.token), emitido.token]
  end

  it 'la invitación va a su mail, con el link que lleva a activar el portal' do
    mail, token = mail_de('invitacion')

    expect(mail.to).to eq(['lucia@example.com'])
    expect(mail.subject).to include('Raíces')
    expect(texto(mail)).to include("/portal/entrar/#{token}")
    expect(texto(mail)).to include('Hola Lucía')
  end

  it 'no lleva el DNI ni nada clínico' do
    mail, = mail_de('invitacion')

    expect(texto(mail)).not_to include('30111222')
    expect(texto(mail)).not_to include('Insomnio')
  end

  it 'el de «me olvidé la clave» lo dice, y que si no lo pidió lo ignore' do
    mail, = mail_de('recuperacion')

    expect(mail.subject).to include('clave nueva')
    expect(texto(mail)).to include('Si no lo pediste')
  end
end
