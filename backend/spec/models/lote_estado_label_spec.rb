require 'rails_helper'

# El estado es uno solo para semilla y esqueje (colapso del 31-jul), pero una semilla que abre no
# enraíza: germina (Germán, 29-sep-2026). Cambia cómo se dice, no la fase.
RSpec.describe Lote, '#estado_label' do
  it 'una semilla que todavía no fue a maceta dice Germinación' do
    expect(Lote.etiqueta_estado('enraizado', 'semilla')).to eq('Germinación')
  end

  it 'un esqueje en el mismo estado sigue diciendo Enraizado' do
    expect(Lote.etiqueta_estado('enraizado', 'esqueje')).to eq('Enraizado')
  end

  it 'sin origen cargado no inventa: Enraizado' do
    expect(Lote.etiqueta_estado('enraizado', nil)).to eq('Enraizado')
  end

  it 'después de prender, el origen no cambia la palabra' do
    expect(Lote.etiqueta_estado('vegetativo', 'semilla')).to eq('Vegetativo')
    expect(Lote.etiqueta_estado('floracion', 'semilla')).to eq('Floración')
  end

  it 'el estado guardado sigue siendo enraizado (setpoints, reglas e informes no cambian)' do
    club = create(:club)
    ActsAsTenant.with_tenant(club) do
      lote = create(:lote, club: club, sala: create(:sala, club: club), estado: 'enraizado', origen: 'semilla')
      expect(lote.reload.estado).to eq('enraizado')
      expect(LoteSerializer.serialize(lote)[:estado_label]).to eq('Germinación')
    end
  end
end
