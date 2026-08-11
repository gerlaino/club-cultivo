require 'rails_helper'

# AC: se puede saber cuánto consume de IA cada organización y cuánto cuesta, y el tope que se
# vende (mensual, por organización) se aplica de verdad.
#
# Los tres bugs que motivan esto: el tope contaba por USUARIO mientras el límite es del club
# (5 usuarios en básico = 100/hora reales), sólo lo chequeaba el asistente, y el consumo no se
# guardaba en ningún lado salvo los tokens de salida del análisis de lote.
RSpec.describe Ia::Uso do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  describe '.registrar' do
    it 'guarda la llamada con su costo congelado' do
      described_class.registrar(club: club, user: admin, funcion: :asistente_parsear,
                                modelo: 'claude-sonnet-4-6',
                                tokens: { input: 1_000_000, output: 1_000_000 })

      llamada = IaLlamada.last
      expect(llamada.funcion).to eq('asistente_parsear')
      # 1M entrada a $3 + 1M salida a $15
      expect(llamada.costo_usd.to_f).to be_within(0.01).of(18.0)
    end

    it 'cobra Haiku más barato que Sonnet con los mismos tokens' do
      described_class.registrar(club: club, funcion: :csv_import, modelo: 'claude-haiku-4-5-20251001',
                                tokens: { input: 1_000_000 })
      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: 'claude-sonnet-4-6',
                                tokens: { input: 1_000_000 })

      haiku, sonnet = IaLlamada.order(:id).to_a
      expect(haiku.costo_usd).to be < sonnet.costo_usd
    end

    it 'un modelo desconocido se cobra al precio más caro, no a cero' do
      described_class.registrar(club: club, funcion: :plan_trabajo, modelo: 'modelo-nuevo-2027',
                                tokens: { input: 1_000_000 })

      # Cobrar de menos pasa desapercibido y factura mal; de más se nota y se corrige.
      expect(IaLlamada.last.costo_usd.to_f).to be > 0
    end

    it 'NO rompe la funcionalidad si el registro falla' do
      # Perder una fila de consumo es malo; romperle el asistente al cultivador es peor.
      allow(IaLlamada).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, 'boom')

      expect {
        described_class.registrar(club: club, funcion: :asistente_parsear, modelo: 'x')
      }.not_to raise_error
    end

    it 'registra también las llamadas fallidas: cuestan igual' do
      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: 'claude-sonnet-4-6',
                                ok: false, error_clase: 'Net::ReadTimeout')

      expect(IaLlamada.last).to have_attributes(ok: false, error_clase: 'Net::ReadTimeout')
    end
  end

  describe '.tokens_de' do
    it 'lee los tokens del cuerpo de la respuesta, incluidos los de caché' do
      leidos = described_class.tokens_de(
        'usage' => { 'input_tokens' => 10, 'output_tokens' => 3,
                     'cache_creation_input_tokens' => 1400, 'cache_read_input_tokens' => 0 }
      )

      expect(leidos).to eq(input: 10, output: 3, cache_creation: 1400, cache_read: 0)
    end

    it 'devuelve ceros si la respuesta no tiene la forma esperada' do
      # La llamada ya salió bien; no vale romperla porque cambió el shape del body.
      expect(described_class.tokens_de(nil)).to eq(input: 0, output: 0, cache_creation: 0, cache_read: 0)
      expect(described_class.tokens_de('otra_cosa' => 1)).to eq(input: 0, output: 0, cache_creation: 0, cache_read: 0)
    end
  end

  # El caché es la optimización principal del asistente: el bloque fijo del prompt son ~1.400
  # tokens que se repiten en cada dictado. Estos casos fijan la aritmética del ahorro.
  describe 'costo con caché de prompt' do
    it 'leer de caché cuesta la décima parte que procesar la misma entrada' do
      lleno   = IaLlamada.costo_de(modelo: 'claude-sonnet-4-6', input_tokens: 1_000_000, output_tokens: 0)
      cacheado = IaLlamada.costo_de(modelo: 'claude-sonnet-4-6', input_tokens: 0, output_tokens: 0,
                                    cache_read_tokens: 1_000_000)

      expect(cacheado).to be_within(0.01).of(lleno * 0.1)
    end

    it 'escribir el caché cuesta 1,25× — se paga una vez y se amortiza' do
      lleno    = IaLlamada.costo_de(modelo: 'claude-sonnet-4-6', input_tokens: 1_000_000, output_tokens: 0)
      escritura = IaLlamada.costo_de(modelo: 'claude-sonnet-4-6', input_tokens: 0, output_tokens: 0,
                                     cache_creation_tokens: 1_000_000)

      expect(escritura).to be_within(0.01).of(lleno * 1.25)
    end

    it 'informa qué porcentaje de la entrada se sirvió de caché' do
      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: 'claude-sonnet-4-6',
                                tokens: { input: 100, cache_read: 900 })

      # Si esto queda en 0 con el asistente en uso, algo está invalidando el prefijo.
      expect(IaLlamada.last.cache_hit_ratio).to eq(90.0)
      expect(described_class.resumen_mes(club)[:cache_hit]).to eq(90.0)
    end
  end

  describe '.limite_alcanzado' do
    before { club.update!(ia_tier: 'basico') } # 500/mes

    it 'deja pasar por debajo del tope' do
      expect(described_class.limite_alcanzado(club, admin)).to be_nil
    end

    it 'corta al llegar al tope mensual y dice cuándo se renueva' do
      allow(club).to receive(:ia_limite_mes).and_return(2)
      2.times { described_class.registrar(club: club, funcion: :asistente_parsear, modelo: 'm') }

      msg = described_class.limite_alcanzado(club, admin)
      expect(msg).to include('2')
      expect(msg).to include('día 1')
    end

    it 'el tope es de la ORGANIZACIÓN, no de cada usuario' do
      allow(club).to receive(:ia_limite_mes).and_return(2)
      otro = create(:user, :cultivador, club: club)
      2.times { described_class.registrar(club: club, user: admin, funcion: :asistente_parsear, modelo: 'm') }

      # El consumo lo gastó `admin`; `otro` NO arranca de cero — es el bug que se está cerrando.
      expect(described_class.limite_alcanzado(club, otro)).to include('tope')
    end

    it 'no cuenta el consumo de otra organización' do
      allow(club).to receive(:ia_limite_mes).and_return(2)
      otro_club = create(:club)
      ActsAsTenant.with_tenant(otro_club) do
        5.times { described_class.registrar(club: otro_club, funcion: :asistente_parsear, modelo: 'm') }
      end

      expect(described_class.limite_alcanzado(club, admin)).to be_nil
    end
  end

  describe '.resumen_mes' do
    it 'suma llamadas, tokens y costo, y desglosa por función' do
      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: 'claude-sonnet-4-6',
                                tokens: { input: 1_000_000 })
      described_class.registrar(club: club, funcion: :analisis_lote, modelo: 'claude-sonnet-4-6',
                                tokens: { input: 1_000_000 })

      r = described_class.resumen_mes(club)
      expect(r[:llamadas]).to eq(2)
      expect(r[:tokens]).to eq(2_000_000)
      expect(r[:costo_usd]).to be_within(0.01).of(6.0)
      expect(r[:por_funcion]).to eq('asistente_parsear' => 1, 'analisis_lote' => 1)
    end
  end
end
