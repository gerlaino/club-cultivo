require 'rails_helper'

# AC (Germán, 15-oct-2026): «fijate cómo se arman los mails, que se muestre sólo la data
# necesaria». Un mail se reenvía y queda en casillas y teléfonos fuera de la app: los avisos
# internos dicen CUÁNTOS y llevan a la app; quiénes son y su salud quedan detrás del login.
# Y uno por destinatario (regla del correo): nunca varios en el mismo `To:`.
RSpec.describe NotificacionesMailer, type: :mailer do
  let(:club) do
    create(:club, name: 'Mi Org', smtp_host: 'smtp.gmail.com', smtp_port: 587, smtp_user: 'm@gmail.com',
                  smtp_pass: 'p', smtp_from: 'm@gmail.com', smtp_from_name: 'Mi Org')
  end
  let!(:admin)  { create(:user, :admin, club: club, email: 'admin@miorg.com') }
  let(:medico)  { create(:user, :medico, club: club, email: 'dra@miorg.com') }
  let(:ana)     { create(:paciente, club: club, created_by: admin, nombre: 'Ana', apellido: 'Quiroga', reprocann_numero: 'RP-778899', reprocann_vencimiento: 5.days.ago.to_date) }
  let(:beto)    { create(:paciente, club: club, created_by: admin, nombre: 'Beto', apellido: 'Salinas', reprocann_vencimiento: 20.days.from_now.to_date) }

  def todo(mail) = [mail.subject, mail.text_part.body.to_s, mail.html_part.body.to_s].join("\n")

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  describe 'REPROCANN por vencer' do
    let(:mail) { described_class.resumen_reprocann(para: admin, club: club, vencidos: [ana], por_vencer: { 30 => [beto] }) }

    it 'dice cuántos, sin nombres ni números de REPROCANN' do
      t = todo(mail)
      expect(t).to include('2 pacientes')
      expect(t).not_to include('Quiroga', 'Salinas', 'RP-778899')
      expect(mail.to).to eq(['admin@miorg.com'])
    end
  end

  describe 'indicaciones médicas por vencer' do
    let(:ind) { create(:indicacion_medica, paciente: ana, user: medico, patologia: 'Epilepsia refractaria') }
    let(:mail) { described_class.resumen_indicaciones(para: medico, club: club, vencidas: [ind], por_vencer: {}) }

    it 'dice cuántas, sin paciente ni patología' do
      t = todo(mail)
      expect(t).to include('1 indicación')
      expect(t).not_to include('Quiroga', 'Epilepsia')
      expect(mail.to).to eq(['dra@miorg.com'])
    end
  end

  it 'los avisos a varios salen de a uno: cada mail con un solo destinatario' do
    create(:user, :admin, club: club, email: 'otra@miorg.com')
    ActionMailer::Base.deliveries.clear

    described_class.a_cada(described_class.admins_de(club), :resumen_reprocann,
                           club: club, vencidos: [ana], por_vencer: {})
    expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly(['admin@miorg.com'], ['otra@miorg.com'])
  end

  it 'si a uno no le sale, a los demás sí' do
    sin_mail = create(:user, :admin, club: club, email: 'x@miorg.com')
    allow(sin_mail).to receive(:email_notificacion).and_raise(StandardError, 'casilla rota')
    ActionMailer::Base.deliveries.clear

    described_class.a_cada([sin_mail, admin], :resumen_reprocann, club: club, vencidos: [ana], por_vencer: {})
    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([['admin@miorg.com']])
  end
end
