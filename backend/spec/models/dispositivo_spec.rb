require 'rails_helper'

RSpec.describe Dispositivo, type: :model do
  let(:club) { create(:club) }
  let(:sala) { create(:sala, club: club) }

  describe '#regenerar_token!' do
    it 'returns a plain token and stores digest' do
      dispositivo = create(:dispositivo, sala: sala)
      plain = dispositivo.regenerar_token!

      expect(plain).to be_present
      expect(plain.length).to eq(64)
      expect(dispositivo.webhook_token_digest).to be_present
      expect(dispositivo.last_token_rotated_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe '#webhook_token_matches?' do
    it 'returns true with correct token' do
      dispositivo = create(:dispositivo, sala: sala)
      plain = dispositivo.regenerar_token!
      expect(dispositivo.webhook_token_matches?(plain)).to be true
    end

    it 'returns false with wrong token' do
      dispositivo = create(:dispositivo, sala: sala)
      dispositivo.regenerar_token!
      expect(dispositivo.webhook_token_matches?('wrong')).to be false
    end

    it 'returns false when no token set' do
      dispositivo = build(:dispositivo)
      expect(dispositivo.webhook_token_matches?('any')).to be false
    end
  end

  describe '#token_pendiente_confirmacion?' do
    it 'returns true after token rotation before next reading' do
      dispositivo = create(:dispositivo, sala: sala)
      dispositivo.regenerar_token!
      expect(dispositivo.token_pendiente_confirmacion?).to be true
    end

    it 'returns false if no token rotation' do
      dispositivo = create(:dispositivo, sala: sala)
      expect(dispositivo.token_pendiente_confirmacion?).to be false
    end
  end
end
