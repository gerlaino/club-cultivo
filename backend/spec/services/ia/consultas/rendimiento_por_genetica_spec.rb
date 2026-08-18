require 'rails_helper'

# AC: el chatbot no contesta con hechos que no tiene. Si no hay ciclos suficientes para comparar
# genéticas, el modelo NO recibe los números — recibe qué falta y qué sí se puede contestar.
#
# El guard vive acá y no en el prompt a propósito: un modelo con dos filas escribe un párrafo
# igual de convencido que con doscientas, y "pocos datos" lo interpretaría él.
RSpec.describe Ia::Consultas::RendimientoPorGenetica do
  let(:club) { create(:club) }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  def genetica!(nombre) = create(:genetica, club: club, nombre: nombre)

  # Un lote cosechado y pesado. `semanas` arma el ciclo real via la fecha de cosecha de la planta.
  def lote_cosechado!(genetica, gramos:, plantas: 10, semanas: 12)
    inicio = (semanas * 7).days.ago.to_date
    lote = create(:lote, club: club, genetica: genetica, start_date: inicio,
                         rendimiento_real_g: gramos, plants_count: plantas,
                         plants_count_cosechadas: plantas)
    create(:plant, lote: lote, club: club, fecha_cosecha: Time.zone.today)
    lote
  end

  subject(:resultado) { described_class.new(club).resolver }

  context 'cuando no hay ciclos suficientes' do
    it 'no devuelve datos: el modelo no puede opinar sobre lo que no tiene' do
      g = genetica!('Amnesia')
      2.times { lote_cosechado!(g, gramos: 500) }

      expect(resultado).not_to be_suficiente
      expect(resultado.datos).to be_nil
      expect(resultado.to_h).not_to have_key(:datos)
    end

    it 'dice qué falta y cuánto hay, en vez de ser una pared' do
      g = genetica!('Amnesia')
      2.times { lote_cosechado!(g, gramos: 500) }

      expect(resultado.falta).to include('3')
      expect(resultado.falta).to include('Amnesia')
      expect(resultado.disponible).to contain_exactly(hash_including(genetica: 'Amnesia', lotes: 2))
    end

    it 'sin ningún lote cosechado también lo dice, sin inventar un cero' do
      genetica!('Amnesia')

      expect(resultado).not_to be_suficiente
      expect(resultado.falta).to be_present
    end
  end

  context 'cuando alcanza para al menos una genética' do
    let!(:critical) { genetica!('Critical') }
    let!(:amnesia)  { genetica!('Amnesia') }

    let!(:northern) { genetica!('Northern') }

    before do
      3.times { lote_cosechado!(critical, gramos: 4_500, plantas: 10, semanas: 12) }
      3.times { lote_cosechado!(northern, gramos: 3_000, plantas: 10, semanas: 10) }
      1.times { lote_cosechado!(amnesia,  gramos: 5_500, plantas: 10, semanas: 17) }
    end

    it 'compara sólo las que llegan al mínimo' do
      expect(resultado).to be_suficiente
      expect(resultado.datos[:geneticas].map { |g| g[:genetica] }).to contain_exactly('Critical', 'Northern')
    end

    it 'nombra las que todavía no, para poder decir "de esa no puedo todavía"' do
      expect(resultado.datos[:todavia_sin_datos])
        .to contain_exactly(hash_including(genetica: 'Amnesia', lotes: 1))
    end

    it 'informa gramos por planta a partir de los lotes reales' do
      critical_fila = resultado.datos[:geneticas].find { |g| g[:genetica] == 'Critical' }

      expect(critical_fila[:g_por_planta]).to eq(450.0)
      expect(critical_fila[:lotes]).to eq(3)
    end

    it 'informa gramos por planta POR SEMANA, que es lo que ordena qué plantar' do
      # El recurso escaso es la sala: 450 g en 12 semanas son 37,5 g por semana de ocupación.
      fila = resultado.datos[:geneticas].find { |g| g[:genetica] == 'Critical' }
      expect(fila[:g_por_planta_por_semana]).to eq(37.5)
    end

    it 'no mezcla el consumo de otra organización' do
      otro_club = create(:club)
      ActsAsTenant.with_tenant(otro_club) do
        g = create(:genetica, club: otro_club, nombre: 'Ajena')
        3.times do
          create(:lote, club: otro_club, genetica: g, start_date: 12.weeks.ago.to_date,
                        rendimiento_real_g: 9_999, plants_count: 1, plants_count_cosechadas: 1)
        end
      end

      expect(resultado.datos[:geneticas].map { |g| g[:genetica] }).to contain_exactly('Critical', 'Northern')
    end
  end

  # Los dos casos que aparecieron al mirar datos REALES de producción, donde ningún club tenía más
  # de una genética con tres lotes y sólo 4 de 10 lotes cosechados tenían fecha de cosecha cargada.
  context 'con UNA sola genética que llega al mínimo' do
    let!(:critical) { genetica!('Critical') }
    let!(:amnesia)  { genetica!('Amnesia') }

    before do
      3.times { lote_cosechado!(critical, gramos: 4_500) }
      1.times { lote_cosechado!(amnesia,  gramos: 5_500) }
    end

    it 'no da por buena la comparación: una sola no compite contra nadie' do
      expect(resultado).not_to be_suficiente
      expect(resultado.falta).to include('una sola')
      expect(resultado.falta).to include('Critical')
    end

    it 'igual manda lo que sabe de esa, para no callarla' do
      expect(resultado.disponible[:unica_con_datos]).to include(genetica: 'Critical', lotes: 3)
    end
  end

  # En producción, la fecha de cosecha estaba cargada en 4 de 10 lotes: vive en cada PLANTA, y un
  # lote sin registros de planta individuales no tiene dónde guardarla. La pesada de cosecha, en
  # cambio, se crea siempre.
  context 'cuando el lote no tiene plantas cargadas' do
    let!(:critical) { genetica!('Critical') }
    let!(:northern) { genetica!('Northern') }

    before do
      3.times do
        lote = create(:lote, club: club, genetica: critical, start_date: 12.weeks.ago.to_date,
                             rendimiento_real_g: 4_500, plants_count: 10, plants_count_cosechadas: 10)
        # Sin un solo `Plant`, como pasa con los lotes cargados en bloque.
        lote.pesadas.create!(fase_origen: 'floracion', fase_destino: 'cosecha',
                             registrado_por: create(:user, :cultivador, club: club),
                             registrado_at: Time.current)
      end
      3.times { lote_cosechado!(northern, gramos: 3_000, semanas: 10) }
    end

    it 'saca el ciclo de la PESADA de cosecha, que siempre existe' do
      fila = resultado.datos[:geneticas].find { |g| g[:genetica] == 'Critical' }

      expect(fila[:lotes_con_ciclo]).to eq(3)
      expect(fila[:semanas_ciclo]).to eq(12.0)
      expect(fila[:g_por_planta_por_semana]).to eq(37.5)
    end
  end

  context 'cuando el ciclo lo sostiene un solo lote' do
    let!(:critical) { genetica!('Critical') }
    let!(:northern) { genetica!('Northern') }

    before do
      # Tres lotes de Critical, pero sólo UNO con fecha de cosecha en las plantas.
      3.times do |i|
        inicio = 12.weeks.ago.to_date
        lote = create(:lote, club: club, genetica: critical, start_date: inicio,
                             rendimiento_real_g: 4_500, plants_count: 10, plants_count_cosechadas: 10)
        create(:plant, lote: lote, club: club, fecha_cosecha: (i.zero? ? Time.zone.today : nil))
      end
      3.times { lote_cosechado!(northern, gramos: 3_000, semanas: 10) }
    end

    it 'NO publica el ciclo: con un lote es el de ese lote, no el de la genética' do
      fila = resultado.datos[:geneticas].find { |g| g[:genetica] == 'Critical' }

      expect(fila[:g_por_planta]).to eq(450.0)   # el rendimiento sí sale de los tres
      expect(fila[:semanas_ciclo]).to be_nil
      expect(fila[:g_por_planta_por_semana]).to be_nil
    end

    it 'dice cuántos lotes sostienen el ciclo, para que la frase no engañe' do
      # "37,5 g por semana sobre 3 lotes" salía con las semanas de UNO solo.
      fila = resultado.datos[:geneticas].find { |g| g[:genetica] == 'Critical' }

      expect(fila[:lotes]).to eq(3)
      expect(fila[:lotes_con_ciclo]).to eq(1)
    end
  end

  # Mezclar plan y real en un mismo promedio es lo que hace que después nadie confíe en el dato.
  it 'un lote sin fecha de cosecha real no rellena el ciclo con el objetivo' do
    g = genetica!('Critical')
    3.times do
      create(:lote, club: club, genetica: g, start_date: 12.weeks.ago.to_date,
                    rendimiento_real_g: 4_500, plants_count: 10, plants_count_cosechadas: 10,
                    dias_floracion_objetivo: 60)
    end
    # Hace falta una segunda genética comparable: con una sola, la consulta ni llega a publicar
    # datos (ver el guard de MINIMO_COMPARABLES).
    northern = genetica!('Northern')
    3.times { lote_cosechado!(northern, gramos: 3_000) }

    fila = resultado.datos[:geneticas].find { |x| x[:genetica] == 'Critical' }
    expect(fila[:g_por_planta]).to eq(450.0)          # el rendimiento sí se puede saber
    expect(fila[:semanas_ciclo]).to be_nil            # el ciclo no, y no se inventa
    expect(fila[:g_por_planta_por_semana]).to be_nil
  end
end
