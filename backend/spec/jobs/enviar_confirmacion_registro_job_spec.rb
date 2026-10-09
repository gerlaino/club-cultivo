require 'rails_helper'

# El reloj de los 7 días corre desde que el mail SALIÓ: si el correo falla, no se anota.
RSpec.describe EnviarConfirmacionRegistroJob do
  let(:reg) do
    Registros::CrearPersonal.new(nombre: 'Juana', email: 'j@ej.com', password: 'clave-larga-1', acepta_terminos: true, mayor_de_edad: true).call
  end

  it 'manda el mail con un link que confirma, y anota cuándo salió' do
    expect { described_class.perform_now(reg.id) }.to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(reg.reload.mail_enviado_at).to be_present
    link = ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{/registro/confirmar\?token=(\S+)}, 1]
    expect(RegistroPersonal.por_token(link)).to eq(reg)
  end

  it 'si el correo falla, no anota el envío (y el job falla para reintentarse)' do
    mail = instance_double(ActionMailer::MessageDelivery)
    allow(mail).to receive(:deliver_now).and_raise(Net::SMTPAuthenticationError.new('535'))
    allow(AccesoMailer).to receive(:confirmar_mail).and_return(mail)
    expect { described_class.perform_now(reg.id) }.to raise_error(Net::SMTPAuthenticationError)
    expect(reg.reload.mail_enviado_at).to be_nil
  end
end
