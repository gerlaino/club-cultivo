require 'rails_helper'

RSpec.describe Club, 'envío de email', type: :model do
  describe '#email_from / #email_reply_to (modo plataforma por defecto)' do
    let(:club) { create(:club, name: 'Mi Club', email: 'contacto@miclub.com') }

    it 'usa el dominio de la plataforma con el nombre del club, y reply-to al email del club' do
      expect(club.email_propio?).to be false
      expect(club.email_from).to eq("Mi Club <#{Club::PLATFORM_FROM}>")
      expect(club.email_reply_to).to eq('contacto@miclub.com')
      expect(club.email_delivery_options).to be_nil # usa la config global
    end
  end

  describe '#email_from (modo propio, club conectó su casilla)' do
    let(:club) do
      create(:club, name: 'Mi Club',
             smtp_host: 'smtp.gmail.com', smtp_port: 587,
             smtp_user: 'miclub@gmail.com', smtp_pass: 'app-pass',
             smtp_from: 'miclub@gmail.com', smtp_from_name: 'Mi Club')
    end

    it 'manda desde la casilla del club y sin reply-to plataforma' do
      expect(club.email_propio?).to be true
      expect(club.email_from).to eq('Mi Club <miclub@gmail.com>')
      expect(club.email_reply_to).to be_nil
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
end
