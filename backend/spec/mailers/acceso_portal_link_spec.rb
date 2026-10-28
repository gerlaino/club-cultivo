require 'rails_helper'

# El mail con el link del portal (invitación o «me olvidé la clave»): va al mail de la ficha, con el
# link y nada más (ni el DNI ni ningún dato de salud). Lo manda la organización: sale por SU casilla
# si la conectó, y si no por la de la plataforma (Germán, 27-oct-2026).
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

  describe 'de qué casilla sale' do
    it 'con el correo de la organización conectado, sale por su casilla y con su nombre' do
      club.update!(smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'raices@gmail.com', smtp_pass: 'app-pass')
      mail, = mail_de('invitacion')

      expect(mail.from).to eq(['raices@gmail.com'])
      expect(mail[:from].display_names).to eq(['Raíces'])
      expect(mail.delivery_method.settings).to include(address: 'smtp.gmail.com', user_name: 'raices@gmail.com')
    end

    it 'el «me olvidé la clave» también sale por la casilla de la organización' do
      club.update!(smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'raices@gmail.com', smtp_pass: 'app-pass')
      mail, = mail_de('recuperacion')

      expect(mail.from).to eq(['raices@gmail.com'])
    end

    it 'sin el correo de la organización conectado, sale igual por la casilla de la plataforma' do
      mail, = mail_de('invitacion')

      expect(mail.from).to eq([Mail::Address.new(Club::PLATFORM_FROM).address])
    end
  end
end
