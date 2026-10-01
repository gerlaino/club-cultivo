require 'rails_helper'

# Un club DEMO se borra entero para poder regenerarlo; uno real, nunca por esta vía.
RSpec.describe Clubs::BorrarDemo do
  let(:club)  { create(:club, demo: true) }
  let(:admin) { create(:user, :admin, club: club) }

  # AC (1-oct-2026): un demo con pesajes de manicura también se borra. Sus pesadas cuelgan del
  # pesaje (`pesaje_manicura_id`), no de una `pesada`, y quedaban bloqueando plantas y lotes.
  it 'borra un demo con lotes, plantas y pesajes de manicura, sin dejar nada' do
    ids = ActsAsTenant.with_tenant(club) do
      sede = create(:sede, club: club, created_by: admin)
      lote = create(:lote, club: club, sala: create(:sala, club: club, sede: sede, created_by: admin))
      planta = create(:plant, lote: lote, peso_seco: 10)
      pesaje = lote.pesajes_manicura.create!(manicurador: admin, club: club, fecha_pesaje: Time.zone.today)
      pesaje.pesadas_plantas.create!(plant: planta, peso_seco_g: 10)
      { lote: lote.id, planta: planta.id, pesaje: pesaje.id }
    end

    described_class.call(club: club)

    ActsAsTenant.without_tenant do
      expect(Club.unscoped.exists?(club.id)).to be(false)
      expect(Lote.unscoped.exists?(ids[:lote])).to be(false)
      expect(Plant.unscoped.exists?(ids[:planta])).to be(false)
      expect(PesadaPlanta.unscoped.where(plant_id: ids[:planta])).to be_empty
    end
  end

  it 'un club que no es demo no se borra' do
    real = create(:club)
    expect { described_class.call(club: real) }.to raise_error(ArgumentError, /no está marcado como demo/)
    expect(Club.exists?(real.id)).to be(true)
  end
end
