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

  # El tope se cuenta en CRÉDITOS, no en llamadas. Contar llamadas medía mal: una importación de
  # plan de trabajo paga hasta 4.096 tokens de salida y un mapeo de CSV 512 — ocho veces menos
  # por el mismo cupo.
  describe Ia::Modelos do
    it 'todo modelo que usamos tiene su precio cargado' do
      # Sin esto, agregar un modelo nuevo lo cobra al precio por defecto sin que nada falle y la
      # facturación queda mal en silencio.
      sin_precio = Ia::Modelos::TODOS.reject { |m| IaLlamada::PRECIOS.key?(m) }

      expect(sin_precio).to be_empty, "sin precio en IaLlamada::PRECIOS: #{sin_precio.join(', ')}"
    end
  end

  describe 'créditos' do
    it 'una llamada cara consume más créditos que una barata' do
      # Esta es la razón entera del cambio: con el conteo por llamadas las dos valían lo mismo.
      barata = IaLlamada.creditos_de(IaLlamada.costo_de(modelo: Ia::Modelos::RAPIDO,
                                                       input_tokens: 0, output_tokens: 512))
      cara   = IaLlamada.creditos_de(IaLlamada.costo_de(modelo: Ia::Modelos::RAZONA,
                                                       input_tokens: 0, output_tokens: 4_096))

      expect(cara).to be > barata
    end

    it 'una llamada que costó algo nunca sale gratis' do
      # Redondeo siempre para arriba: el error de redondeo queda de nuestro lado.
      minima = IaLlamada.creditos_de(0.0001)
      expect(minima).to eq(1)
    end

    it 'una llamada sin costo no consume crédito' do
      expect(IaLlamada.creditos_de(0)).to eq(0)
    end
  end

  describe '.limite_alcanzado' do
    before { club.update!(ia_tier: 'basico') } # 500 créditos/mes

    it 'deja pasar por debajo del tope' do
      expect(described_class.limite_alcanzado(club, admin)).to be_nil
    end

    it 'corta al gastar los créditos del mes y dice cuándo se renuevan' do
      allow(club).to receive(:ia_limite_mes).and_return(2)
      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: Ia::Modelos::RAZONA,
                                tokens: { output: 1_000 }) # US$0,015 → 2 créditos

      msg = described_class.limite_alcanzado(club, admin)
      expect(msg).to include('2')
      expect(msg).to include('día 1')
    end

    it 'las llamadas FALLIDAS no le descuentan cupo al cliente' do
      # Una mala tarde de la API no la puede pagar la organización: se registra para verla, pero
      # no consume. Antes se contaba el mes entero sin mirar `ok`.
      allow(club).to receive(:ia_limite_mes).and_return(2)
      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: Ia::Modelos::RAZONA,
                                ok: false, error_clase: 'Net::ReadTimeout',
                                tokens: { output: 100_000 }) # gastaría de sobra si contara

      expect(described_class.limite_alcanzado(club, admin)).to be_nil
    end

    it 'el tope es de la ORGANIZACIÓN, no de cada usuario' do
      allow(club).to receive(:ia_limite_mes).and_return(2)
      otro = create(:user, :cultivador, club: club)
      described_class.registrar(club: club, user: admin, funcion: :asistente_parsear,
                                modelo: Ia::Modelos::RAZONA, tokens: { output: 1_000 })

      # El consumo lo gastó `admin`; `otro` NO arranca de cero — es el bug que se está cerrando.
      expect(described_class.limite_alcanzado(club, otro)).to include('créditos')
    end

    it 'no cuenta el consumo de otra organización' do
      allow(club).to receive(:ia_limite_mes).and_return(2)
      otro_club = create(:club)
      ActsAsTenant.with_tenant(otro_club) do
        5.times do
          described_class.registrar(club: otro_club, funcion: :asistente_parsear,
                                    modelo: Ia::Modelos::RAZONA, tokens: { output: 1_000 })
        end
      end

      expect(described_class.limite_alcanzado(club, admin)).to be_nil
    end
  end

  # Lo que ve el admin en el medidor. Sale de la misma fuente que el tope a propósito: si
  # contaran distinto, la pantalla diría "te quedan 40" con el dictado ya rechazado.
  describe '.consumo' do
    before { allow(club).to receive(:ia_limite_mes).and_return(100) }

    it 'informa cuánto queda y en qué porcentaje va' do
      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: Ia::Modelos::RAZONA,
                                tokens: { output: 10_000 }) # US$0,15 → 15 créditos

      c = described_class.consumo(club)
      expect(c[:creditos]).to eq(15)
      expect(c[:restantes]).to eq(85)
      expect(c[:porcentaje]).to eq(15)
      expect(c[:agotado]).to be(false)
    end

    it 'avisa a partir del 80%, antes de chocar' do
      # Enterarse al chocar es el peor momento: la persona ya está trabajando.
      expect(described_class.consumo(club)[:avisar]).to be(false)

      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: Ia::Modelos::RAZONA,
                                tokens: { output: 55_000 }) # US$0,825 → 83 créditos

      expect(described_class.consumo(club)[:avisar]).to be(true)
    end

    it 'nunca informa restantes en negativo ni más de 100%' do
      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: Ia::Modelos::RAZONA,
                                tokens: { output: 500_000 }) # muy por encima del tope

      c = described_class.consumo(club)
      expect(c[:restantes]).to eq(0)
      expect(c[:porcentaje]).to eq(100)
      expect(c[:agotado]).to be(true)
    end

    it 'dice cuántos días faltan para que se renueve' do
      viaja = Date.new(2026, 8, 20)
      expect(described_class.consumo(club, viaja)[:dias_restantes]).to eq(12)
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

    it 'muestra créditos junto al costo: uno es lo que compra el cliente, el otro lo que sale' do
      # Los dos en la misma pantalla es lo que deja ver si el add-on se vende por debajo del costo.
      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: Ia::Modelos::RAZONA,
                                tokens: { output: 10_000 }) # US$0,15 → 15 créditos

      r = described_class.resumen_mes(club)
      expect(r[:creditos]).to eq(15)
      expect(r[:costo_usd]).to be_within(0.01).of(0.15)
    end

    it 'cuenta la llamada fallida pero no su crédito' do
      # Se ve que pasó —para poder investigarla— sin que se la cobremos a la organización.
      described_class.registrar(club: club, funcion: :asistente_parsear, modelo: Ia::Modelos::RAZONA,
                                ok: false, tokens: { output: 10_000 })

      r = described_class.resumen_mes(club)
      expect(r[:llamadas]).to eq(1)
      expect(r[:creditos]).to eq(0)
    end
  end
end
