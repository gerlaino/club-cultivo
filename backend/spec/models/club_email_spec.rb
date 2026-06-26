require 'rails_helper'

RSpec.describe Club, 'envío de email', type: :model do
  describe 'sin correo conectado' do
    let(:club) { create(:club, name: 'Mi Club') }

    it 'queda sin configurar y no puede enviar' do
      expect(club.email_propio?).to be false
      expect(club.email_modo).to eq('sin_configurar')
    end

    it 'un mailer no entrega nada si el club no conectó su correo' do
      mail_enviado = build_mail_enviado(club)
      expect {
        PacienteMailer.mensaje(mail_enviado: mail_enviado).deliver_now
      }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end

  describe 'con su casilla conectada' do
    let(:club) do
      create(:club, name: 'Mi Club',
             smtp_host: 'smtp.gmail.com', smtp_port: 587,
             smtp_user: 'miclub@gmail.com', smtp_pass: 'app-pass',
             smtp_from: 'miclub@gmail.com', smtp_from_name: 'Mi Club')
    end

    it 'manda desde la casilla del club' do
      expect(club.email_propio?).to be true
      expect(club.email_modo).to eq('propio')
      expect(club.email_from).to eq('Mi Club <miclub@gmail.com>')
      expect(club.email_delivery_options[:address]).to eq('smtp.gmail.com')
    end
  end

  describe '.smtp_provider_for' do
    it 'autodetecta el servidor por dominio' do
      expect(Club.smtp_provider_for('x@gmail.com')[:host]).to eq('smtp.gmail.com')
      expect(Club.smtp_provider_for('x@outlook.com')[:host]).to eq('smtp.office365.com')
      expect(Club.smtp_provider_for('x@dominioraro.com')).to be_nil
    end
  end

  def build_mail_enviado(club)
    paciente = create(:paciente, club: club, email: 'p@test.com')
    user     = create(:user, :admin, club: club)
    MailEnviado.create!(club: club, paciente: paciente, user: user,
                        asunto: 'Hola', cuerpo: 'Cuerpo', tipo: 'personalizado',
                        email_destino: 'p@test.com', enviado_at: Time.current)
  end
end
