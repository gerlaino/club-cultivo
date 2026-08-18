require 'rails_helper'

# AC: el admin pregunta cuánto le cuesta el gramo por genética y el chatbot contesta SÓLO sobre
# los lotes que tienen el costo cargado, diciendo cuántos son — y acotado a una ventana, porque
# los costos están en pesos y comparar contra un lote viejo compara inflación, no genéticas.
RSpec.describe Ia::Consultas::CostoPorGenetica do
  let(:club)  { create(:club) }
  let(:sala)  { create(:sala, club: club) }
  let(:admin) { create(:user, :admin, club: club) }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  # `CostoLote` recalcula `costo_total` y `costo_por_gramo` al guardar, así que el costo por gramo
  # se fija por los INSUMOS y los gramos, no seteándolo a mano.
  def lote_con_costo!(genetica, costo_gramo:, meses_atras: 1)
    lote = create(:lote, club: club, sala: sala, genetica: genetica,
                         start_date: meses_atras.months.ago.to_date,
                         rendimiento_real_g: 1_000, plants_count: 10)
    CostoLote.create!(lote: lote, club: club, costo_insumos: costo_gramo * 1_000,
                      gramos_producidos: 1_000, calculado_por: admin)
    lote
  end

  subject(:resultado) { described_class.new(club).resolver }

  it 'sin lotes con costo cargado lo dice, en vez de promediar la nada' do
    g = create(:genetica, club: club, nombre: 'Critical')
    create(:lote, club: club, sala: sala, genetica: g, start_date: 1.month.ago.to_date,
                  rendimiento_real_g: 1_000)

    expect(resultado).not_to be_suficiente
    expect(resultado.falta).to include('costo cargado')
  end

  it 'con menos del mínimo dice cuántos hay de cuántos' do
    g = create(:genetica, club: club, nombre: 'Critical')
    2.times { lote_con_costo!(g, costo_gramo: 100) }

    expect(resultado).not_to be_suficiente
    expect(resultado.disponible.first).to include(genetica: 'Critical', lotes_con_costo: 2)
  end

  context 'con suficientes lotes' do
    let!(:critical) { create(:genetica, club: club, nombre: 'Critical') }

    before do
      lote_con_costo!(critical, costo_gramo: 100)
      lote_con_costo!(critical, costo_gramo: 200)
      lote_con_costo!(critical, costo_gramo: 300)
    end

    it 'informa el promedio y también el rango' do
      # El rango importa tanto como el promedio: si va de 100 a 300, el promedio no describe nada
      # y lo que hay que mirar es por qué varían tanto entre sí.
      fila = resultado.datos[:geneticas].first

      expect(fila[:costo_por_gramo]).to eq(200.0)
      expect(fila[:minimo]).to eq(100.0)
      expect(fila[:maximo]).to eq(300.0)
      expect(fila[:lotes_con_costo]).to eq(3)
    end

    it 'deja afuera lo más viejo que la ventana: eso compara inflación, no genéticas' do
      lote_con_costo!(critical, costo_gramo: 5, meses_atras: 12) # precios de otro año

      expect(resultado.datos[:geneticas].first[:lotes_con_costo]).to eq(3)
      expect(resultado.datos[:geneticas].first[:minimo]).to eq(100.0)
    end

    it 'dice desde cuándo está mirando, para que el número se pueda discutir' do
      expect(resultado.datos[:ventana_meses]).to eq(described_class::VENTANA_MESES)
      expect(resultado.datos[:desde]).to be_present
      expect(resultado.datos[:nota]).to include('inflación')
    end
  end
end
