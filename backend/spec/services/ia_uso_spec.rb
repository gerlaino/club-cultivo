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
                                input_tokens: 1_000_000, output_tokens: 1_000_000)

      llamada = IaLlamada.last
      expect(llamada.funcion).to eq('asistente_parsear')
      # 1M entrada a $3 + 1M salida a $15
      expect(llamada.costo_usd.to_f).to be_within(0.01).of(18.0)
    end

    it 'cobra Haiku más barato que Sonnet con los mismos tokens' do
      described_class.registrar(club: club, funcion: :csv_import, modelo: 'claude-haiku-4-5-20251001',
                                input_tokens: 1_000_000, output_tokens: 0)
      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: 'claude-sonnet-4-6',
                                input_tokens: 1_000_000, output_tokens: 0)

      haiku, sonnet = IaLlamada.order(:id).to_a
      expect(haiku.costo_usd).to be < sonnet.costo_usd
    end

    it 'un modelo desconocido se cobra al precio más caro, no a cero' do
      described_class.registrar(club: club, funcion: :plan_trabajo, modelo: 'modelo-nuevo-2027',
                                input_tokens: 1_000_000, output_tokens: 0)

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
    it 'lee los tokens del cuerpo de la respuesta' do
      expect(described_class.tokens_de('usage' => { 'input_tokens' => 10, 'output_tokens' => 3 }))
        .to eq([10, 3])
    end

    it 'devuelve ceros si la respuesta no tiene la forma esperada' do
      # La llamada ya salió bien; no vale romperla porque cambió el shape del body.
      expect(described_class.tokens_de(nil)).to eq([0, 0])
      expect(described_class.tokens_de('otra_cosa' => 1)).to eq([0, 0])
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
                                input_tokens: 1_000_000, output_tokens: 0)
      described_class.registrar(club: club, funcion: :analisis_lote, modelo: 'claude-sonnet-4-6',
                                input_tokens: 1_000_000, output_tokens: 0)

      r = described_class.resumen_mes(club)
      expect(r[:llamadas]).to eq(2)
      expect(r[:tokens]).to eq(2_000_000)
      expect(r[:costo_usd]).to be_within(0.01).of(6.0)
      expect(r[:por_funcion]).to eq('asistente_parsear' => 1, 'analisis_lote' => 1)
    end
  end
end
