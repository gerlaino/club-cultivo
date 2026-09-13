require 'rails_helper'

# LA ANALÍTICA COMPARA: qué genética, cuánto tarda cada fase, en qué sala y con qué método, a qué
# costo — sobre los lotes cerrados con rendimiento, todo el historial por defecto. Lo que se fija
# acá son las reglas que hacían que la analítica vieja dijera números plausibles que no eran los
# reales: promedio de promedios, «merma» siempre 0, una fase `secado` que no existe, el costo de
# lotes abiertos dividido por gramos de cerrados.
RSpec.describe 'Analitica' do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:vege)  { create(:sala, club: club, sede: sede, kind: 'vegetativo', nombre: 'Vege') }
  let(:flora1) { create(:sala, club: club, sede: sede, kind: 'floracion', nombre: 'Flora 1') }
  let(:flora2) { create(:sala, club: club, sede: sede, kind: 'floracion', nombre: 'Flora 2') }
  let(:kush)  { create(:genetica, club: club, nombre: 'Critical Kush') }
  let(:haze)  { create(:genetica, club: club, nombre: 'Haze') }

  def universo(desde: nil, hasta: nil) = Analitica::Universo.new(club: club, desde: desde, hasta: hasta)

  # Un lote cerrado con su cronología completa: arranca en `inicio`, vege 30 días, floración en
  # `sala_flora` los días que se pidan, corte, manicura 5 días, curado.
  def cerrado!(genetica, inicio:, plantas:, gramos:, flora_dias: 60, sala_flora: flora1, descartadas: 0,
               no_prendio: 0, grow_type: 'sustrato', light_type: nil, costo: nil, origen: 'esqueje')
    l = create(:lote, club: club, sala: vege, genetica: genetica, estado: 'curado', start_date: inicio,
                      rendimiento_real_g: gramos, plants_count_cosechadas: plantas - descartadas - no_prendio,
                      grow_type: grow_type, light_type: light_type, origen: origen)
    (plantas - descartadas - no_prendio).times { create(:plant, lote: l, club: club, state: 'cosechado') }
    descartadas.times { create(:plant, lote: l, club: club, state: 'descartada', motivo_descarte: 'plaga') }
    no_prendio.times  { create(:plant, lote: l, club: club, state: 'descartada', motivo_descarte: 'no_prendio') }
    t = inicio.to_time
    ev = ->(estado, dias, sala = nil) { l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: estado, club: club, user: admin,
                                                                 registrado_en: t + dias.days, sala_destino: sala) }
    ev.call('enraizado', 0); ev.call('vegetativo', 10, vege); ev.call('floracion', 40, sala_flora)
    ev.call('cosecha', 40 + flora_dias); ev.call('en_manicura', 48 + flora_dias); ev.call('curado', 53 + flora_dias)
    l.create_costo_lote!(costo_insumos: costo, gramos_producidos: gramos) if costo
    l
  end

  describe Analitica::Universo do
    it 'son los lotes cerrados con rendimiento; con período, los cosechados en él' do
      cerrado!(kush, inicio: Date.new(2026, 1, 1), plantas: 10, gramos: 300)              # corte ~11/03
      cerrado!(kush, inicio: Date.new(2025, 6, 1), plantas: 10, gramos: 300)              # corte ~08/2025
      create(:lote, club: club, sala: flora1, genetica: kush, estado: 'floracion')         # abierto

      expect(universo.lotes.size).to eq(2)
      expect(universo(desde: Date.new(2026, 1, 1).beginning_of_day, hasta: Date.new(2026, 12, 31).end_of_day).lotes.size).to eq(1)
    end

    it 'cuenta las fases reales del lote: la cosecha es el secado y termina en la manicura' do
      l = cerrado!(kush, inicio: Date.new(2026, 1, 1), plantas: 10, gramos: 300, flora_dias: 60)
      f = universo.fases[l.id]

      expect(f['enraizado']).to eq(10.0)
      expect(f['vegetativo']).to eq(30.0)
      expect(f['floracion']).to eq(60.0)
      expect(f['cosecha']).to eq(8.0)
      expect(f['en_manicura']).to eq(5.0)
      expect(f['total']).to eq(113.0)   # 10 + 30 + 60 + 8 + 5: lo que suman las columnas
    end
  end

  describe Analitica::Geneticas do
    it 'g/planta PONDERADO: un lote de 3 plantas no pesa lo mismo que uno de 40' do
      cerrado!(kush, inicio: Date.new(2026, 1, 1), plantas: 40, gramos: 1200)   # 30 g/planta
      cerrado!(kush, inicio: Date.new(2026, 2, 1), plantas: 4,  gramos: 200)    # 50 g/planta
      cerrado!(kush, inicio: Date.new(2026, 3, 1), plantas: 6,  gramos: 180)    # 30 g/planta

      fila = described_class.new(universo).call.first
      expect(fila[:nombre]).to eq('Critical Kush')
      expect(fila[:g_por_planta]).to eq(31.6)   # 1580 / 50, no (30+50+30)/3
      expect(fila[:suficientes]).to be(true)
    end

    # La analítica vieja dividía por `plants_count`, que ya excluye las descartadas: daba 0.
    it 'lo que se perdió en el ciclo se cuenta con TODAS las plantas, y aparte de lo que no prendió' do
      cerrado!(kush, inicio: Date.new(2026, 1, 1), plantas: 20, gramos: 500, descartadas: 2, no_prendio: 4)

      fila = described_class.new(universo).call.first
      expect(fila[:prendio_pct]).to eq(80.0)    # 16 de 20 enraizaron
      expect(fila[:perdida_pct]).to eq(12.5)    # 2 de las 16 que prendieron
      expect(fila[:plantas]).to eq(14)
    end

    it 'con menos de tres lotes la fila va sin conclusión, al final' do
      cerrado!(kush, inicio: Date.new(2026, 1, 1), plantas: 10, gramos: 300)
      3.times { |i| cerrado!(haze, inicio: Date.new(2026, 1, 1 + i), plantas: 10, gramos: 250) }

      filas = described_class.new(universo).call
      expect(filas.map { |f| [f[:nombre], f[:suficientes]] }).to eq([['Haze', true], ['Critical Kush', false]])
    end
  end

  describe Analitica::Fases do
    it 'días promedio por fase real, con el prendimiento y el origen adelante' do
      cerrado!(kush, inicio: Date.new(2026, 1, 1), plantas: 10, gramos: 300, flora_dias: 60, origen: 'esqueje')
      cerrado!(kush, inicio: Date.new(2026, 2, 1), plantas: 10, gramos: 300, flora_dias: 70, origen: 'semilla', no_prendio: 2)

      fila = described_class.new(universo).call.first
      expect(fila[:dias]['floracion']).to eq(65)
      expect(fila[:dias]['en_manicura']).to eq(5)
      expect(fila[:dias]['total']).to eq(118)
      expect(fila[:prendio_pct]).to eq(90.0)
      expect(fila[:origen_label]).to eq('1 de esqueje · 1 de semilla')
    end
  end

  describe Analitica::DondeYComo do
    it 'corta por la sala de FLORACIÓN (no la del lote, que la pierde al cosechar) y dice cuál rinde mejor' do
      3.times { |i| cerrado!(kush, inicio: Date.new(2026, 1, 1 + i), plantas: 10, gramos: 340, sala_flora: flora1) }
      3.times { |i| cerrado!(kush, inicio: Date.new(2026, 2, 1 + i), plantas: 10, gramos: 290, sala_flora: flora2) }

      r = described_class.new(universo, corte: 'sala').call
      expect(r[:filas].map { |f| [f[:nombre], f[:g_por_planta], f[:mejor]] }).to eq([['Flora 1', 34.0, true], ['Flora 2', 29.0, false]])
      expect(r[:filas].last[:contra_mejor_pct]).to eq(-15)
      expect(r[:con_lecturas]).to be(false)
    end

    # En producción el evento de floración no lleva sala y el lote la pierde al cosecharse: 25 de 25
    # salían «Sin dato». La sala de la que SALIÓ al cortarse sí queda escrita.
    it 'sin sala en el evento de floración, toma la sala de la que salió al cortarse' do
      l = cerrado!(kush, inicio: Date.new(2026, 1, 1), plantas: 10, gramos: 300, sala_flora: nil)
      l.lote_eventos.find_by(estado_nuevo: 'cosecha').update!(sala_origen: flora2)
      l.update_column(:sala_id, nil)

      r = described_class.new(universo, corte: 'sala').call
      expect(r[:filas].map { |f| f[:nombre] }).to eq(['Flora 2'])
    end

    it 'el ambiente es el de la sala DURANTE la floración del lote, sensores incluidos' do
      l = cerrado!(kush, inicio: Date.new(2026, 1, 1), plantas: 10, gramos: 300, sala_flora: flora1)
      [[Date.new(2026, 2, 20), 1.2], [Date.new(2026, 3, 1), 1.4]].each do |fecha, vpd|   # en floración
        create(:lectura_ambiental, sala: flora1, tipo: 'vpd', valor: vpd, unidad: 'kPa', medido_at: fecha.to_time + 12.hours, fuente: 'backfill')
      end
      create(:lectura_ambiental, sala: flora1, tipo: 'vpd', valor: 0.6, unidad: 'kPa', medido_at: Date.new(2026, 1, 15).to_time, fuente: 'backfill')  # antes de florecer
      create(:lectura_ambiental, sala: flora1, tipo: 'temperatura', valor: 25, unidad: '°C', medido_at: Date.new(2026, 2, 25).to_time, fuente: 'backfill')

      r = described_class.new(universo, corte: 'sala').call
      amb = r[:filas].first[:ambiente]
      expect(amb['vpd']).to eq(1.3)
      expect(amb['temperatura']).to eq(25.0)
      expect(amb['humedad']).to be_nil
      expect(r[:con_lecturas]).to be(true)
      expect(l.reload.sala_id).to eq(vege.id)   # el lote sigue apuntando a la sala vieja: no sirve para cortar
    end

    it 'corta por método y por luz' do
      cerrado!(kush, inicio: Date.new(2026, 1, 1), plantas: 10, gramos: 300, grow_type: 'hidroponia', light_type: 'led')
      cerrado!(kush, inicio: Date.new(2026, 2, 1), plantas: 10, gramos: 200, grow_type: 'sustrato')

      expect(described_class.new(universo, corte: 'metodo').call[:filas].map { |f| f[:nombre] }).to eq(['Hidroponia', 'Sustrato'])
      expect(described_class.new(universo, corte: 'luz').call[:filas].map { |f| f[:nombre] }).to eq(['Led', 'Sin dato'])
    end
  end

  describe Analitica::Costo do
    it 'sólo lotes cerrados con costo: el costo de un lote abierto no se divide por gramos que no existen' do
      cerrado!(kush, inicio: Date.new(2026, 1, 1), plantas: 10, gramos: 400, costo: 100_000)
      cerrado!(haze, inicio: Date.new(2026, 1, 1), plantas: 10, gramos: 100, costo: 50_000)
      cerrado!(haze, inicio: Date.new(2026, 2, 1), plantas: 10, gramos: 100)   # sin costo cargado
      abierto = create(:lote, club: club, sala: flora1, genetica: kush, estado: 'floracion')
      abierto.create_costo_lote!(costo_insumos: 999_999)

      r = described_class.new(universo).call
      expect(r[:total][:costo_por_gramo]).to eq(300.0)    # 150.000 / 500
      expect(r[:total][:lotes_sin_costo]).to eq(1)
      expect(r[:por_genetica].map { |f| [f[:nombre], f[:costo_por_gramo]] }).to eq([['Critical Kush', 250.0], ['Haze', 500.0]])
    end
  end
end
