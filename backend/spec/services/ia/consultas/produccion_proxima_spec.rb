require 'rails_helper'

# AC: el admin pregunta qué va a cosechar y el chatbot contesta con lo que hay hoy en las salas.
#
# El bug que motiva parte de esto: el chatbot contestaba "no tengo los días en floración" mientras
# la tabla de lotes mostraba "3d" en pantalla. El dato existía y esta consulta no lo miraba — la
# misma regla en dos lados que dejan de coincidir.
RSpec.describe Ia::Consultas::ProduccionProxima do
  let(:club) { create(:club) }
  let(:sala)  { create(:sala, club: club) }
  let(:admin) { create(:user, :admin, club: club) }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  subject(:resultado) { described_class.new(club).resolver }

  it 'sin lotes en curso lo dice, en vez de contestar cero' do
    expect(resultado).not_to be_suficiente
    expect(resultado.falta).to include('floración')
  end

  context 'con un lote en floración' do
    let!(:lote) do
      create(:lote, club: club, sala: sala, estado: 'floracion',
                    start_date: 40.days.ago.to_date, plants_count: 10)
    end

    it 'informa hace cuántos días está en esa fase' do
      # Entró a floración hace 3 días; el lote arrancó hace 40.
      LoteEvento.create!(lote: lote, club: club, user: admin, tipo: 'cambio_estado',
                         estado_nuevo: 'floracion', registrado_en: 3.days.ago)

      fila = resultado.datos[:lotes].first
      expect(fila[:dias_en_fase]).to eq(3)
      expect(fila[:dias_desde_inicio]).to eq(40)
    end

    it 'sin evento de cambio de estado cuenta desde el arranque del lote' do
      # Un lote creado ya en floración nunca registró el cambio: igual se puede decir hace cuánto.
      expect(resultado.datos[:lotes].first[:dias_en_fase]).to eq(40)
    end

    it 'dice de dónde sale cada estimado, porque el origen cambia cuánto vale' do
      lote.update!(rendimiento_objetivo_g: 4_000)

      fila = resultado.datos[:lotes].first
      expect(fila[:gramos_estimados]).to eq(4_000)
      expect(fila[:estimado_segun]).to eq('objetivo cargado')
    end

    it 'un lote ya pesado deja de ser estimación' do
      lote.update!(rendimiento_real_g: 3_500, estado: 'curado')

      fila = resultado.datos[:lotes].first
      expect(fila[:estimado_segun]).to eq('pesado real')
      expect(fila[:gramos_estimados]).to eq(3_500)
    end

    it 'sin ninguna base para estimar lo avisa en vez de poner un cero' do
      # Un cero se lee como "no va a rendir nada", que es una afirmación que nadie hizo.
      fila = resultado.datos[:lotes].first
      expect(fila[:gramos_estimados]).to be_nil
      expect(resultado.datos[:advertencia]).to include('sin base para estimar')
    end

    it 'no mira lotes de otra organización' do
      otro = create(:club)
      ActsAsTenant.with_tenant(otro) do
        create(:lote, club: otro, sala: create(:sala, club: otro), estado: 'floracion',
                      start_date: 10.days.ago.to_date, plants_count: 99)
      end

      expect(resultado.datos[:lotes].size).to eq(1)
      expect(resultado.datos[:lotes].first[:lote]).to eq(lote.codigo)
    end
  end
end
