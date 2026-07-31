require 'rails_helper'

# Los TRES relojes del lote. El ciclo se cuenta desde que entra a VEGETATIVO, no desde el esqueje:
# en el domo la planta no crece, emite raíz —ni siquiera come, por eso su registro no lleva EC ni
# pH—. Contar el enraizado como vegetativo hace que un lote que tardó 20 días en prender aparente
# 20 días más de vege sin haber hecho un nudo más.
RSpec.describe Lote, 'los relojes del ciclo' do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }

  # Un lote que arrancó hace 40 días y prendió a los 12: 12 enraizando + 28 de ciclo.
  def lote_que_prendio(dias_total: 40, dias_enraizando: 12, estado: 'vegetativo')
    lote = create(:lote, club: club, sala: sala, estado: estado,
                         start_date: dias_total.days.ago.to_date, tamanio_maceta: 3)
    lote.lote_eventos.create!(
      tipo: 'cambio_estado', estado_anterior: 'enraizado', estado_nuevo: 'vegetativo',
      registrado_en: (dias_total - dias_enraizando).days.ago, club: club, user: admin,
    )
    lote
  end

  describe '#dias_enraizado' do
    it 'cuenta del inicio hasta que prendió' do
      expect(lote_que_prendio.dias_enraizado).to eq(12)
    end

    # Mientras sigue adentro del domo el número corre: es el que mira al clonador y el que se
    # estira cuando se muere una manta térmica, antes de que caiga el prendimiento.
    it 'va corriendo mientras el lote sigue enraizando' do
      lote = create(:lote, club: club, sala: sala, estado: 'enraizado', start_date: 9.days.ago.to_date)
      expect(lote.dias_enraizado).to eq(9)
    end
  end

  describe '#dias_ciclo' do
    it 'arranca en vegetativo, no en el esqueje' do
      lote = lote_que_prendio(dias_total: 40, dias_enraizando: 12)
      expect(lote.dias_ciclo).to eq(28)
      expect(lote.dias_desde_inicio).to eq(40)   # la edad de la planta sigue siendo 40
    end

    it 'todavía no arrancó mientras enraíza' do
      lote = create(:lote, club: club, sala: sala, estado: 'enraizado', start_date: 5.days.ago.to_date)
      expect(lote.dias_ciclo).to be_nil
    end

    # Sin este fallback, los lotes viejos y los heredados —que no tienen el evento— se quedarían
    # sin métricas de golpe.
    it 'cae a start_date en un lote sin evento de vegetativo' do
      viejo = create(:lote, club: club, sala: sala, estado: 'floracion',
                            start_date: 30.days.ago.to_date, tamanio_maceta: 3)
      expect(viejo.dias_ciclo).to eq(30)
    end
  end

  describe 'los días de vegetación que ve la UI' do
    it 'no incluyen el enraizado' do
      lote = lote_que_prendio(dias_total: 40, dias_enraizando: 12, estado: 'floracion')
      lote.lote_eventos.create!(
        tipo: 'cambio_estado', estado_anterior: 'vegetativo', estado_nuevo: 'floracion',
        registrado_en: 5.days.ago, club: club, user: admin,
      )

      data = LoteSerializer.serialize(lote.reload)

      expect(data[:dias_enraizado]).to eq(12)
      expect(data[:dias_vegetacion]).to eq(23)   # 40 - 12 enraizando - 5 en floración
    end
  end
end
