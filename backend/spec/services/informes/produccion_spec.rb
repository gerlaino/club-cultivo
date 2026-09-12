require 'rails_helper'

# EL INFORME DE PRODUCCIÓN LE HABLA AL ADMIN, en tres marcos de tiempo: lo cosechado del período
# (contra el anterior), la foto de hoy y lo que viene. Lo que se fija acá son las reglas que
# hacían que el informe viejo dijera números plausibles que no eran los reales.
RSpec.describe Informes::Produccion do
  let(:club)     { create(:club, plan: 'basico') }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'produccion', nombre: 'Centro') }
  let(:sala)     { create(:sala, sede: sede, club: club, kind: 'mixta', nombre: 'Flora 1') }
  let(:genetica) { create(:genetica, club: club, nombre: 'Critical Kush', tiempo_floracion: 60) }

  let(:desde) { Time.zone.today.beginning_of_month.beginning_of_day }
  let(:hasta) { Time.zone.today.end_of_month.end_of_day }

  def informe(d = desde, h = hasta) = described_class.new(club: club, desde: d, hasta: h).call

  def lote!(estado:, plantas: 0, **attrs)
    l = create(:lote, club: club, sala: sala, estado: estado, genetica: genetica, **attrs)
    plantas.times { create(:plant, lote: l, club: club, state: estado) }
    l
  end

  def cosechado!(cuando:, gramos: nil, plantas: 10, **attrs)
    l = lote!(estado: 'curado', plants_count_cosechadas: plantas, rendimiento_real_g: gramos, **attrs)
    l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin, registrado_en: cuando)
    l
  end

  describe 'lo que se cosechó' do
    # COSECHADO ES CUANDO SE CORTA, no cuando se pesa (decisión de Germán, sep-2026): el lote
    # cosechado en agosto y pesado en septiembre es producción de agosto.
    it 'atribuye los gramos al período del corte aunque se hayan pesado después' do
      cosechado!(cuando: 1.month.ago.beginning_of_month + 5.days, gramos: 500)

      anterior = informe(1.month.ago.beginning_of_month.beginning_of_day, 1.month.ago.end_of_month.end_of_day)
      expect(anterior[:periodo][:gramos]).to eq(500.0)
      expect(anterior[:periodo][:total_lotes]).to eq(1)
      expect(informe[:periodo][:total_lotes]).to eq(0)
    end

    # El informe viejo contaba por `updated_at`: corregirle una nota a un lote del año pasado lo
    # traía al mes de hoy.
    it 'editar un lote viejo no lo mueve de período' do
      l = cosechado!(cuando: 8.months.ago, gramos: 300)
      l.update!(fertilizacion_descripcion: 'corregido hoy')

      expect(informe[:periodo][:total_lotes]).to eq(0)
    end

    it 'lista el lote sin peso y lo cuenta aparte, sin sumarlo a los gramos' do
      cosechado!(cuando: desde + 1.day, gramos: 400, plantas: 10)
      cosechado!(cuando: desde + 2.days, gramos: nil)

      per = informe[:periodo]
      expect(per[:total_lotes]).to eq(2)
      expect(per[:sin_peso]).to eq(1)
      expect(per[:gramos]).to eq(400.0)
      expect(per[:gramos_por_planta]).to eq(40.0)   # sólo sobre lo pesado
      expect(per[:lotes].map { |f| f[:gramos] }).to contain_exactly(400.0, nil)
    end

    it 'compara con el período inmediato anterior de la misma duración' do
      cosechado!(cuando: desde + 1.day, gramos: 600)
      cosechado!(cuando: desde - 3.days, gramos: 500)

      per = informe[:periodo]
      expect(per[:anterior][:gramos]).to eq(500.0)
      expect(per[:variacion][:gramos]).to eq(20.0)
    end

    it 'sin período anterior no inventa una variación' do
      cosechado!(cuando: desde + 1.day, gramos: 600)

      expect(informe[:periodo][:variacion][:gramos]).to be_nil
    end
  end

  describe 'hoy en el cultivo' do
    # «Plantas en pie» excluía `finalizado` —que no es un estado de planta— y dejaba adentro a
    # las descartadas y a las que están en secado.
    it 'una planta descartada o en secado no está en pie' do
      l = lote!(estado: 'floracion', plantas: 3)
      create(:plant, lote: l, club: club, state: 'descartada')
      create(:plant, lote: l, club: club, state: 'secado')

      hoy = informe[:hoy]
      expect(hoy[:plantas_en_pie]).to eq(3)
      expect(informe[:por_sede].first[:plantas]).to eq(3)
    end

    it 'separa lo que está en pie de lo que está en proceso' do
      lote!(estado: 'vegetativo')
      lote!(estado: 'floracion')
      lote!(estado: 'en_manicura')
      create(:lote, club: club, sala: nil, sede: sede, estado: 'finalizado')

      hoy = informe[:hoy]
      expect(hoy[:lotes_en_pie]).to eq(2)
      expect(hoy[:lotes_en_proceso]).to eq(1)
      expect(hoy[:por_estado].map { |e| e[:estado] }).not_to include('finalizado')
    end

    # Cortada no es desaparecida: en cosecha cuelga y en manicura se pesa una por una. En curado
    # ya es flor en frasco, y ahí la celda va vacía (nil), que no es lo mismo que cero plantas.
    it 'cuenta las plantas cortadas en cosecha y manicura, y nada en curado' do
      cosecha = lote!(estado: 'cosecha')
      3.times { create(:plant, lote: cosecha, club: club, state: 'cosechado') }
      create(:plant, lote: cosecha, club: club, state: 'secado')
      create(:plant, lote: cosecha, club: club, state: 'descartada')
      manicura = lote!(estado: 'en_manicura')
      2.times { create(:plant, lote: manicura, club: club, state: 'cosechado') }
      curado = lote!(estado: 'curado')
      create(:plant, lote: curado, club: club, state: 'cosechado')

      hoy = informe[:hoy]
      por = hoy[:por_estado].to_h { |e| [e[:estado], e[:plantas]] }
      expect(por).to eq('cosecha' => 4, 'en_manicura' => 2, 'curado' => nil)
      expect(hoy[:plantas_en_pie]).to eq(0)
    end

    # Un estado sin tiempo no es un dato: «2 lotes en floración» es normal, «uno lleva 80 días
    # con objetivo de 60» es un lote que alguien tiene que mirar.
    it 'marca el más viejo sólo cuando supera el objetivo que heredó de la genética' do
      viejo = lote!(estado: 'floracion', dias_floracion_objetivo: 60)
      viejo.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'floracion', club: club, user: admin, registrado_en: 80.days.ago)
      joven = lote!(estado: 'floracion', dias_floracion_objetivo: 60)
      joven.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'floracion', club: club, user: admin, registrado_en: 10.days.ago)

      fila = informe[:hoy][:por_estado].find { |e| e[:estado] == 'floracion' }
      expect(fila[:mas_viejo]).to include(codigo: viejo.codigo, dias: 80, objetivo: 60, excedido: true)
      expect(fila[:dias_promedio]).to eq(45)
    end

    it 'sin objetivo no marca nada' do
      l = lote!(estado: 'floracion', dias_floracion_objetivo: nil)
      l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'floracion', club: club, user: admin, registrado_en: 200.days.ago)

      fila = informe[:hoy][:por_estado].find { |e| e[:estado] == 'floracion' }
      expect(fila[:mas_viejo][:excedido]).to be(false)
    end

    it 'muestra la ocupación contra el tope sólo cuando el plan lo tiene' do
      lote!(estado: 'vegetativo', plantas: 2)

      expect(informe[:hoy][:plan]).to include(tope: 450, cuentan: 2)

      club.update!(plan: 'total')
      expect(informe[:hoy][:plan]).to be_nil
    end
  end

  describe 'lo que viene' do
    it 'estima con el g/planta histórico de esa genética en esta organización' do
      cosechado!(cuando: 1.year.ago, gramos: 300, plantas: 10)   # 30 g/planta de Critical Kush
      prox = lote!(estado: 'floracion', plantas: 4, fecha_cosecha_estimada: Time.zone.today + 12)

      fila = informe[:proximas].find { |p| p[:codigo] == prox.codigo }
      expect(fila).to include(plantas: 4, dias: 12, gramos_por_planta_ref: 30.0, estimado: 120)
    end

    it 'sin historia no estima, y sin fecha estimada la deduce de la entrada a floración' do
      otra = create(:genetica, club: club, nombre: 'Sin historia', tiempo_floracion: 60)
      l = lote!(estado: 'floracion', plantas: 4, genetica: otra, dias_floracion_objetivo: 60)
      l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'floracion', club: club, user: admin, registrado_en: 50.days.ago)

      fila = informe[:proximas].first
      expect(fila[:estimado]).to be_nil
      expect(fila[:dias]).to eq(10)
    end

    it 'ordena por fecha y deja al final lo que no tiene ninguna' do
      con = lote!(estado: 'floracion', fecha_cosecha_estimada: Time.zone.today + 5)
      sin = lote!(estado: 'floracion')

      expect(informe[:proximas].map { |p| p[:codigo] }).to eq([con.codigo, sin.codigo])
    end
  end

  it 'no mira lotes de otra organización' do
    otro = create(:club)
    ActsAsTenant.with_tenant(otro) do
      otro_admin = create(:user, :admin, club: otro)
      otra_sede  = create(:sede, club: otro, created_by: otro_admin, tipo: 'produccion')
      otra_sala  = create(:sala, sede: otra_sede, club: otro, kind: 'mixta')
      l = create(:lote, club: otro, sala: otra_sala, estado: 'floracion', rendimiento_real_g: 900,
                        plants_count_cosechadas: 10)
      create(:plant, lote: l, club: otro, state: 'floracion')
      l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: otro, user: otro_admin, registrado_en: desde + 1.day)
    end

    r = informe
    expect(r[:periodo][:total_lotes]).to eq(0)
    expect(r[:hoy][:plantas_en_pie]).to eq(0)
    expect(r[:proximas]).to be_empty
  end
end
