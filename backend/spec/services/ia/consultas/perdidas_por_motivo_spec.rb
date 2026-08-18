require 'rails_helper'

# AC: el admin pregunta qué se le muere y el chatbot contesta con sus descartes reales — o dice
# que todavía no hay con qué, en vez de calcular un porcentaje sobre cinco plantas.
RSpec.describe Ia::Consultas::PerdidasPorMotivo do
  let(:club) { create(:club) }
  let(:sala) { create(:sala, club: club) }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  def plantas!(n, lote:, state: 'vegetativo', motivo: nil)
    n.times { create(:plant, lote: lote, club: club, state: state, motivo_descarte: motivo) }
  end

  subject(:resultado) { described_class.new(club).resolver }

  it 'con pocas plantas no calcula un porcentaje: sería ruido' do
    lote = create(:lote, club: club, sala: sala)
    plantas!(5, lote: lote, state: 'descartada', motivo: 'plaga')

    expect(resultado).not_to be_suficiente
    expect(resultado.datos).to be_nil
    expect(resultado.falta).to include('30')
  end

  context 'con suficientes plantas' do
    let(:genetica) { create(:genetica, club: club, nombre: 'Critical') }
    let!(:lote)    { create(:lote, club: club, sala: sala, genetica: genetica) }

    before do
      plantas!(35, lote: lote)
      plantas!(6,  lote: lote, state: 'descartada', motivo: 'plaga')
      plantas!(4,  lote: lote, state: 'descartada', motivo: 'no_prendio')
    end

    it 'informa cuántas se perdieron y en qué proporción' do
      expect(resultado).to be_suficiente
      expect(resultado.datos[:plantas_totales]).to eq(45)
      expect(resultado.datos[:descartadas]).to eq(10)
      expect(resultado.datos[:porcentaje]).to eq(22.2)
    end

    it 'desglosa POR MOTIVO, que es lo que deja juzgar si el número es malo' do
      # "22% de pérdidas" no se puede juzgar solo: por no prendió en propagación es esperable,
      # por plaga no.
      expect(resultado.datos[:por_motivo]).to include(
        hash_including(motivo: 'plaga', plantas: 6),
        hash_including(motivo: 'no_prendio', plantas: 4)
      )
    end

    it 'por genética usa SU denominador, no el total' do
      # Lo que importa no es cuántas murieron sino qué proporción de las que se plantaron: 50
      # sobre 500 está mejor que 20 sobre 40.
      fila = resultado.datos[:por_genetica].find { |f| f[:genetica] == 'Critical' }

      expect(fila[:plantadas]).to eq(45)
      expect(fila[:descartadas]).to eq(10)
      expect(fila[:porcentaje]).to eq(22.2)
    end

    it 'no cuenta plantas de otra organización' do
      otro = create(:club)
      ActsAsTenant.with_tenant(otro) do
        l = create(:lote, club: otro, sala: create(:sala, club: otro))
        50.times { create(:plant, lote: l, club: otro, state: 'descartada', motivo_descarte: 'plaga') }
      end

      expect(resultado.datos[:plantas_totales]).to eq(45)
    end
  end
end
