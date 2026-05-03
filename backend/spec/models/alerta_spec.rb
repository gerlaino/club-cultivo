require 'rails_helper'

RSpec.describe Alerta, type: :model do
  let(:club) { create(:club) }
  let(:sala) { create(:sala, club: club) }
  let(:user) { create(:user, club: club) }

  describe '#reconocer!' do
    it 'transitions to reconocida and records user' do
      alerta = create(:alerta, sala: sala, club_id: club.id)
      alerta.reconocer!(user)

      expect(alerta.reload.estado).to eq('reconocida')
      expect(alerta.reconocida_por).to eq(user)
      expect(alerta.reconocida_at).to be_present
    end
  end

  describe '#resolver!' do
    it 'transitions to resuelta and records user' do
      alerta = create(:alerta, sala: sala, club_id: club.id)
      alerta.resolver!(user)

      expect(alerta.reload.estado).to eq('resuelta')
      expect(alerta.resuelta_por).to eq(user)
      expect(alerta.resuelta_at).to be_present
    end
  end

  describe 'scopes' do
    let!(:activa)    { create(:alerta, sala: sala, club_id: club.id, estado: 'activa') }
    let!(:resuelta)  { create(:alerta, sala: sala, club_id: club.id, estado: 'resuelta') }

    it '.no_resueltas returns active and recognized alerts' do
      expect(Alerta.no_resueltas).to include(activa)
      expect(Alerta.no_resueltas).not_to include(resuelta)
    end

    it '.del_club scopes to club' do
      otra = create(:alerta)
      expect(Alerta.del_club(club.id)).to include(activa)
      expect(Alerta.del_club(club.id)).not_to include(otra)
    end
  end
end
