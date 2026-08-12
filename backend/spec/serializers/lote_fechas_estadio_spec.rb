require 'rails_helper'

# En la tabla de lotes, "12d en fase" solo no dice nada: hay que poder ver DESDE CUÁNDO.
RSpec.describe 'Fechas de estadío del lote', type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def lote_con_historia
    ActsAsTenant.with_tenant(club) do
      lote = create(:lote, club: club, estado: 'vegetativo', start_date: 40.days.ago.to_date)
      [['vegetativo', 40], ['floracion', 20], ['vegetativo', 10]].each do |estado, hace|
        LoteEvento.create!(lote: lote, club: club, user: admin, tipo: 'cambio_estado',
                           estado_nuevo: estado, registrado_en: hace.days.ago)
      end
      lote
    end
  end

  it 'la fecha del estado actual y los días en fase salen del mismo cálculo' do
    json = LoteSerializer.serialize(lote_con_historia)

    expect(json[:fecha_estado_actual]).to eq(10.days.ago.to_date)
    expect(json[:dias_en_estado]).to eq(10)
    # Si se contradijeran, la tabla mostraría una fecha que no cierra con sus propios días.
    expect((Date.current - json[:fecha_estado_actual]).to_i).to eq(json[:dias_en_estado])
  end

  # Un lote que se avanzó por error y volvió: lo que interesa es desde cuándo está DONDE ESTÁ.
  it 'toma la última entrada a cada estado, no la primera' do
    json = LoteSerializer.serialize(lote_con_historia)
    veg = json[:historial_estados].find { |h| h[:estado] == 'vegetativo' }

    expect(veg[:fecha]).to eq(10.days.ago.to_date)
    expect(veg[:fecha]).not_to eq(40.days.ago.to_date)
  end

  it 'devuelve la línea de tiempo ordenada, un renglón por estadío' do
    json = LoteSerializer.serialize(lote_con_historia)

    expect(json[:historial_estados].map { |h| h[:estado] }).to eq(%w[floracion vegetativo])
    fechas = json[:historial_estados].map { |h| h[:fecha] }
    expect(fechas).to eq(fechas.sort)
  end

  # Los lotes viejos y los heredados no tienen eventos: caen en start_date en vez de quedar en
  # blanco, igual que ya hacía `dias_en_estado`.
  it 'un lote sin eventos usa su fecha de inicio' do
    lote = ActsAsTenant.with_tenant(club) { create(:lote, club: club, start_date: 5.days.ago.to_date) }
    json = LoteSerializer.serialize(lote)

    expect(json[:fecha_estado_actual]).to eq(5.days.ago.to_date)
    expect(json[:historial_estados]).to eq([])
  end
end
