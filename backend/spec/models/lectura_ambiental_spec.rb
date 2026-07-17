require 'rails_helper'

RSpec.describe LecturaAmbiental, type: :model do
  let(:club) { create(:club) }
  let(:sala) { create(:sala, club: club) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      lectura = build(:lectura_ambiental, sala: sala)
      expect(lectura).to be_valid
    end

    it 'rejects unknown tipo' do
      lectura = build(:lectura_ambiental, sala: sala, tipo: 'sabor')
      expect(lectura).not_to be_valid
      expect(lectura.errors[:tipo]).to be_present
    end

    it 'rejects wrong unidad for tipo' do
      lectura = build(:lectura_ambiental, sala: sala, tipo: 'temperatura', unidad: 'lux')
      expect(lectura).not_to be_valid
      expect(lectura.errors[:unidad]).to be_present
    end

    it 'rejects future medido_at for webhook source' do
      lectura = build(:lectura_ambiental, sala: sala, fuente: 'webhook', medido_at: 10.minutes.from_now)
      expect(lectura).not_to be_valid
      expect(lectura.errors[:medido_at]).to be_present
    end

    it 'rejects medido_at older than 7 days for webhook source' do
      lectura = build(:lectura_ambiental, sala: sala, fuente: 'webhook', medido_at: 8.days.ago)
      expect(lectura).not_to be_valid
    end

    it 'allows old medido_at for manual source' do
      lectura = build(:lectura_ambiental, sala: sala, fuente: 'manual', medido_at: 30.days.ago)
      expect(lectura).to be_valid
    end
  end

  describe 'scopes' do
    let!(:reciente)  { create(:lectura_ambiental, sala: sala, medido_at: 1.hour.ago) }
    let!(:antigua)   { create(:lectura_ambiental, sala: sala, medido_at: 3.days.ago, fuente: 'backfill') }
    let!(:otra_sala) { create(:lectura_ambiental, medido_at: 1.hour.ago) }

    it '.de_sala filters by sala' do
      expect(LecturaAmbiental.de_sala(sala.id)).to include(reciente, antigua)
      expect(LecturaAmbiental.de_sala(sala.id)).not_to include(otra_sala)
    end

    it '.no_backfill excludes backfill' do
      expect(LecturaAmbiental.no_backfill).to include(reciente)
      expect(LecturaAmbiental.no_backfill).not_to include(antigua)
    end

    it '.ultimas_n_minutos returns recent records' do
      expect(LecturaAmbiental.ultimas_n_minutos(120)).to include(reciente)
      expect(LecturaAmbiental.ultimas_n_minutos(120)).not_to include(antigua)
    end
  end
end
