require 'rails_helper'

# AC: la trazabilidad tiene que decir QUÉ SE LE APLICÓ al producto, no sólo de qué plantas salió.
#
# Es un resumen y no un log a propósito: sesenta riegos uno abajo del otro no los lee nadie. Lo
# que contesta "¿qué le pusieron a esto?" es la lista de productos distintos y cuántas veces se
# hizo cada cosa.
RSpec.describe Lotes::ResumenAplicaciones do
  let(:club)  { create(:club) }
  let(:sala)  { create(:sala, club: club) }
  let(:lote)  { create(:lote, club: club, sala: sala) }
  let(:user)  { create(:user, :cultivador, club: club) }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  def registro!(dias_atras: 1, **attrs)
    RegistroAmbiental.create!({ lote: lote, club: club, user: user,
                                registrado_en: dias_atras.days.ago }.merge(attrs))
  end

  subject(:resumen) { described_class.new(lote).call }

  it 'sin registros devuelve vacío, no nil: la trazabilidad se dibuja igual' do
    expect(resumen[:registros]).to eq(0)
    expect(resumen[:fitosanitarios]).to eq([])
  end

  it 'cuenta cuántas veces se hizo cada actividad' do
    registro!(dias_atras: 5, tareas_realizadas: %w[riego])
    registro!(dias_atras: 3, tareas_realizadas: %w[riego nutricion])
    registro!(dias_atras: 1, tareas_realizadas: %w[poda])

    expect(resumen[:actividades]).to eq('riego' => 2, 'nutricion' => 1, 'poda' => 1)
  end

  it 'lista los productos SIN REPETIR: importa con qué, no cuántas veces' do
    registro!(dias_atras: 5, fertilizacion: true, notas_fertilizacion: 'Base A+B')
    registro!(dias_atras: 3, fertilizacion: true, notas_fertilizacion: 'Base A+B')
    registro!(dias_atras: 1, fertilizacion: true, notas_fertilizacion: 'Bloom')

    expect(resumen[:nutricion][:veces]).to eq(3)
    expect(resumen[:nutricion][:productos]).to contain_exactly('Base A+B', 'Bloom')
  end

  describe 'fitosanitarios' do
    it 'van SEPARADOS de la nutrición' do
      # Mezclar un fungicida con el bloom en una misma lista es exactamente lo que no puede pasar
      # en un producto medicinal.
      registro!(dias_atras: 4, fertilizacion: true, notas_fertilizacion: 'Bloom')
      registro!(dias_atras: 2, fitosanitario: 'Azufre micronizado',
                               fitosanitario_motivo: 'oidio', carencia_dias: 14)

      expect(resumen[:nutricion][:productos]).to eq(['Bloom'])
      expect(resumen[:fitosanitarios].size).to eq(1)
      expect(resumen[:fitosanitarios].first).to include(
        producto: 'Azufre micronizado', motivo: 'oidio', carencia_dias: 14
      )
    end

    it 'no se agrupan: cada aplicación va con su fecha' do
      # A diferencia de los riegos, acá cada evento importa por sí mismo — la carencia se cuenta
      # desde la ÚLTIMA aplicación.
      registro!(dias_atras: 20, fitosanitario: 'Azufre', carencia_dias: 14)
      registro!(dias_atras: 5,  fitosanitario: 'Azufre', carencia_dias: 14)

      expect(resumen[:fitosanitarios].size).to eq(2)
      expect(resumen[:fitosanitarios].map { |f| f[:fecha] }).to all(be_present)
    end
  end

  it 'una plaga informa desde cuándo y hasta cuándo se vio' do
    # Una plaga que aparece una vez no es lo mismo que una que estuvo seis semanas.
    registro!(dias_atras: 30, plagas_observadas: 'trips')
    registro!(dias_atras: 10, plagas_observadas: 'trips')
    registro!(dias_atras: 1,  plagas_observadas: 'ninguna')

    plaga = resumen[:plagas].find { |p| p[:plaga] == 'trips' }
    expect(plaga[:veces]).to eq(2)
    expect(plaga[:desde].to_date).to eq(30.days.ago.to_date)
    expect(plaga[:hasta].to_date).to eq(10.days.ago.to_date)
    expect(resumen[:plagas].map { |p| p[:plaga] }).not_to include('ninguna')
  end
end
