require 'rails_helper'

RSpec.describe 'Lote#avanzar_fase! hacia cosecha', type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala_flora) { create(:sala, club: club, sede: sede, tipo: 'floracion', kind: 'floracion', created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala_flora, estado: 'floracion') }

  it 'saca el lote de la sala de floración y lo manda a una sala de proceso de cosecha' do
    expect(lote.estado).to eq('floracion')
    expect(lote.sala).to eq(sala_flora)

    lote.avanzar_fase!(usuario: admin)
    lote.reload

    expect(lote.estado).to eq('cosecha')
    expect(lote.sala).not_to eq(sala_flora)
    expect(lote.sala.tipo).to eq('cosecha')
    expect(lote.sala.sede).to eq(sede)
  end

  it 'el lote cosechado ya no aparece entre los lotes de la sala de floración' do
    lote.avanzar_fase!(usuario: admin)
    expect(sala_flora.lotes.where(estado: 'floracion')).to be_empty
    expect(sala_flora.reload.lotes).not_to include(lote.reload)
  end
end
