require 'rails_helper'

RSpec.describe ReglaAmbiental, type: :model do
  let(:club) { create(:club) }

  describe '#viola?' do
    let(:regla_gt)   { build(:regla_ambiental, condicion: 'gt',  umbral_a: 30) }
    let(:regla_lt)   { build(:regla_ambiental, condicion: 'lt',  umbral_a: 10) }
    let(:regla_rango) do
      build(:regla_ambiental, condicion: 'out_of_range', umbral_a: 18, umbral_b: 30)
    end

    it 'returns true when value exceeds threshold (gt)' do
      expect(regla_gt.viola?(31)).to be true
      expect(regla_gt.viola?(29)).to be false
    end

    it 'returns true when value is below threshold (lt)' do
      expect(regla_lt.viola?(9)).to be true
      expect(regla_lt.viola?(11)).to be false
    end

    it 'returns true when value is out of range' do
      expect(regla_rango.viola?(17)).to be true
      expect(regla_rango.viola?(31)).to be true
      expect(regla_rango.viola?(24)).to be false
    end
  end

  describe 'validations' do
    it 'requires umbral_b for between condition' do
      regla = build(:regla_ambiental, condicion: 'between', umbral_b: nil)
      expect(regla).not_to be_valid
      expect(regla.errors[:umbral_b]).to be_present
    end

    it 'is valid without umbral_b for gt condition' do
      regla = build(:regla_ambiental, condicion: 'gt', umbral_b: nil)
      expect(regla).to be_valid
    end
  end

  describe '#alerta_activa_para?' do
    let(:sala)  { create(:sala, club: club) }
    let(:regla) { create(:regla_ambiental, club: club) }

    it 'returns true if there is an active alert for the sala' do
      create(:alerta, regla: regla, sala: sala, club_id: club.id, estado: 'activa')
      expect(regla.alerta_activa_para?(sala.id)).to be true
    end

    it 'returns false when all alerts are resolved' do
      create(:alerta, regla: regla, sala: sala, club_id: club.id, estado: 'resuelta')
      expect(regla.alerta_activa_para?(sala.id)).to be false
    end
  end
end
