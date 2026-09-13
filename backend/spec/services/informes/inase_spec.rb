require 'rails_helper'

# EL INFORME INASE SE PRESENTA ANTE EL ORGANISMO: una fila por variedad del Catálogo, con las
# genéticas propias que acredita, cuánto se cosechó de cada una EN EL PERÍODO y de dónde vino el
# material (semilla / esqueje). Lo que no está vinculado no se esconde ni abre el informe con un
# KPI en grande: sale en la misma tabla, marcado, y arriba un aviso que lo nombra — sólo sobre lo
# que aparece en el documento (decisiones de Germán, 12-sep-2026).
RSpec.describe Informes::Inase do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:sala)  { create(:sala, sede: sede, club: club, kind: 'mixta') }

  let(:inscripta) do
    ActsAsTenant.without_tenant do
      Genetica.create!(nombre: 'TROPICANA WFC', global: true, club_id: nil, registrada_inase: true, criador: 'Wild Flowers')
    end
  end
  let(:tropi)    { create(:genetica, club: club, nombre: 'Tropi 2',  declarada_como: inscripta) }
  let(:naranja)  { create(:genetica, club: club, nombre: 'Naranja',  declarada_como: inscripta) }
  let(:amarillo) { create(:genetica, club: club, nombre: 'Amarillo') }   # sin vincular

  let(:desde) { Time.zone.today.beginning_of_year.beginning_of_day }
  let(:hasta) { Time.zone.today.end_of_year.end_of_day }

  def informe(d = desde, h = hasta) = described_class.new(club: club, desde: d, hasta: h).call

  def cosechado!(genetica, cuando:, gramos:, semilla: 0, esqueje: 0)
    l = create(:lote, club: club, sala: sala, genetica: genetica, estado: 'curado', rendimiento_real_g: gramos,
                      plants_count_cosechadas: semilla + esqueje)
    semilla.times { create(:plant, lote: l, club: club, state: 'cosechado', origen: 'semilla') }
    esqueje.times { create(:plant, lote: l, club: club, state: 'cosechado', origen: 'esqueje') }
    l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin, registrado_en: cuando)
    l
  end

  def en_pie!(genetica, plantas: 3)
    l = create(:lote, club: club, sala: sala, genetica: genetica, estado: 'vegetativo')
    plantas.times { create(:plant, lote: l, club: club, state: 'vegetativo', origen: 'esqueje') }
    l
  end

  it 'una fila por variedad del Catálogo, con las genéticas propias que acredita' do
    cosechado!(tropi,   cuando: desde + 10.days, gramos: 300, semilla: 10)
    cosechado!(naranja, cuando: desde + 20.days, gramos: 200, esqueje: 5)

    filas = informe[:variedades]
    expect(filas.size).to eq(1)
    fila = filas.first
    expect(fila[:nombre]).to eq('TROPICANA WFC')
    expect(fila[:vinculada]).to be(true)
    expect(fila[:acredita]).to eq(['Naranja', 'Tropi 2'])
    expect(fila[:criador]).to eq('Wild Flowers')
    expect(fila[:lotes]).to eq(2)
    expect(fila[:gramos]).to eq(500.0)
  end

  # Era el único informe sin período: contaba de toda la vida.
  it 'cuenta lo cosechado EN EL PERÍODO, por fecha de corte' do
    cosechado!(tropi, cuando: desde + 10.days, gramos: 300, semilla: 10)
    cosechado!(tropi, cuando: desde - 40.days, gramos: 999, semilla: 10)   # el año pasado

    expect(informe[:kpis][:gramos]).to eq(300.0)
    expect(informe[:kpis][:lotes]).to eq(1)
  end

  it 'dice cuántas plantas vinieron de semilla y cuántas de esqueje' do
    cosechado!(tropi, cuando: desde + 10.days, gramos: 300, semilla: 7, esqueje: 3)

    fila = informe[:variedades].first
    expect(fila[:plantas]).to eq(10)
    expect(fila[:origen]).to eq({ 'semilla' => 7, 'esqueje' => 3 })
  end

  it 'un lote sin plantas registradas una por una usa su contador y el origen del lote' do
    l = create(:lote, club: club, sala: sala, genetica: tropi, estado: 'finalizado', rendimiento_real_g: 100,
                      plants_count_cosechadas: 12, origen: 'esqueje')
    l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin, registrado_en: desde + 1.day)

    expect(informe[:variedades].first[:origen]).to eq({ 'semilla' => 0, 'esqueje' => 12 })
  end

  describe 'lo que no está vinculado' do
    it 'sale en la MISMA tabla, con su nombre propio y marcado, y arriba el aviso lo nombra' do
      cosechado!(tropi,    cuando: desde + 10.days, gramos: 300, semilla: 10)
      cosechado!(amarillo, cuando: desde + 12.days, gramos: 100, semilla: 4)

      datos = informe
      fila = datos[:variedades].find { |v| v[:nombre] == 'Amarillo' }
      expect(fila[:vinculada]).to be(false)
      expect(fila[:gramos]).to eq(100.0)
      expect(datos[:sin_vincular].map { |g| g[:nombre] }).to eq(['Amarillo'])
      expect(datos[:geneticas_sin_vincular_ids]).to eq([amarillo.id])
      # Los KPIs cuentan variedades acreditadas; la no vinculada no es una variedad todavía.
      expect(datos[:kpis][:variedades]).to eq(1)
      # Pero sus gramos son gramos: lo cosechado es lo cosechado.
      expect(datos[:kpis][:gramos]).to eq(400.0)
    end

    # El candado de «Para presentar» miraba TODAS las genéticas del club, archivadas y nunca
    # cultivadas incluidas: bloqueaba la descarga por una variedad que no aparecía en ningún lado.
    it 'una genética sin vincular que NO aparece en el informe no genera aviso' do
      amarillo   # existe, sin lotes
      cosechado!(tropi, cuando: desde + 10.days, gramos: 300, semilla: 10)

      expect(informe[:sin_vincular]).to be_empty
      expect(informe[:geneticas_sin_vincular_ids]).to eq([])
    end

    it 'una sin vincular con lotes sólo en pie SÍ entra al aviso cuando el período llega a hoy' do
      en_pie!(amarillo)

      expect(informe[:sin_vincular].map { |g| g[:nombre] }).to eq(['Amarillo'])
    end
  end

  describe 'en cultivo hoy' do
    it 'lista lo en pie por variedad, con su origen, sólo si el período incluye hoy' do
      en_pie!(tropi, plantas: 4)

      datos = informe
      expect(datos[:periodo][:incluye_hoy]).to be(true)
      expect(datos[:en_cultivo].first).to include(nombre: 'TROPICANA WFC', lotes: 1, plantas: 4,
                                                  origen: { 'semilla' => 0, 'esqueje' => 4 })

      pasado = informe(1.year.ago.beginning_of_year.beginning_of_day, 1.year.ago.end_of_year.end_of_day)
      expect(pasado[:periodo][:incluye_hoy]).to be(false)
      expect(pasado[:en_cultivo]).to be_empty
    end
  end
end
