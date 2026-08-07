require 'rails_helper'

# El VPD que se calculaba era el del AIRE. El que gobierna la transpiración —y con el que se
# decide un riego— es el de HOJA: la hoja transpira y se enfría respecto del aire, y ese par
# de grados mueve el número lo suficiente como para cambiar una decisión.
#
# Es también por qué NO coincidía con lo que muestra la app de un sensor Pulse: los dos
# números eran correctos, medían cosas distintas.
RSpec.describe Ambiente::VpdCalculator do
  describe 'hoja vs aire' do
    # 26 °C y 60 % de humedad, el caso típico de una sala en floración.
    it 'el VPD de hoja es MENOR que el de aire' do
      hoja = described_class.call(temperatura: 26, humedad: 60)
      aire = described_class.call(temperatura: 26, humedad: 60, offset_hoja: 0)

      expect(hoja).to be < aire
    end

    it 'la diferencia alcanza para cambiar una decisión' do
      hoja = described_class.call(temperatura: 26, humedad: 60)
      aire = described_class.call(temperatura: 26, humedad: 60, offset_hoja: 0)

      # 0.97 (hoja) contra 1.35 (aire) kPa: el de hoja cae en el rango cómodo de floración y
      # el de aire se va arriba. Con el mismo aire, uno dice "está bien" y el otro "regá".
      expect(hoja).to be_within(0.02).of(0.97)
      expect(aire).to be_within(0.02).of(1.35)
      expect(aire - hoja).to be_within(0.05).of(0.38)
    end

    it 'sin ajuste devuelve exactamente el VPD del aire' do
      expect(described_class.call(temperatura: 25, humedad: 50, offset_hoja: 0))
        .to eq((0.6108 * Math.exp(17.27 * 25 / (25 + 237.3)) * 0.5).round(3))
    end
  end

  describe 'el ajuste por sala' do
    # Bajo LED la hoja se enfría más que bajo HPS, donde el infrarrojo la calienta.
    it 'una hoja más fría da un VPD más bajo' do
      led = described_class.call(temperatura: 26, humedad: 60, offset_hoja: -3)
      hps = described_class.call(temperatura: 26, humedad: 60, offset_hoja: -1)

      expect(led).to be < hps
    end

    it 'el valor por defecto es el que usa la industria' do
      expect(described_class::OFFSET_HOJA_DEFAULT).to eq(-2.0)
    end
  end

  describe 'casos límite' do
    it 'con 100 % de humedad el VPD es 0: el aire no admite más vapor' do
      expect(described_class.call(temperatura: 24, humedad: 100, offset_hoja: 0)).to eq(0.0)
    end

    # Con la hoja más fría que el aire y el aire saturado, la cuenta da negativo (habría
    # condensación sobre la hoja). Un VPD negativo no significa nada: se corta en 0.
    it 'nunca devuelve un VPD negativo' do
      expect(described_class.call(temperatura: 24, humedad: 100)).to eq(0.0)
    end

    it 'más calor y menos humedad, más VPD' do
      seco   = described_class.call(temperatura: 30, humedad: 30)
      humedo = described_class.call(temperatura: 20, humedad: 80)

      expect(seco).to be > humedo
    end
  end

  describe 'la lectura que guarda la app' do
    let(:club)  { create(:club) }
    let(:admin) { create(:user, :admin, club: club) }
    let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }

    # `club_id` en LecturaAmbiental es una columna suelta: no hay belongs_to ni acts_as_tenant,
    # así que lo setea quien crea la lectura (ver Sensors::BaseDriver#persist!).

    # El ajuste es POR SALA: dos salas con el mismo aire pueden tener distinto VPD de hoja
    # según con qué luz trabajen.
    it 'usa el ajuste de hoja de la sala, no uno global' do
      led = create(:sala, sede: sede, club: club, kind: 'floracion', leaf_temp_offset: -3)
      hps = create(:sala, sede: sede, club: club, kind: 'floracion', leaf_temp_offset: -1)

      [led, hps].each do |sala|
        LecturaAmbiental.create!(club_id: club.id, sala: sala, tipo: 'temperatura', valor: 26,
                                 unidad: '°C', medido_at: Time.current, fuente: 'manual')
        LecturaAmbiental.create!(club_id: club.id, sala: sala, tipo: 'humedad', valor: 60,
                                 unidad: '%', medido_at: Time.current, fuente: 'manual')
      end

      vpd_led = LecturaAmbiental.find_by(sala: led, tipo: 'vpd')&.valor&.to_f
      vpd_hps = LecturaAmbiental.find_by(sala: hps, tipo: 'vpd')&.valor&.to_f

      expect(vpd_led).to be_present
      expect(vpd_hps).to be_present
      expect(vpd_led).to be < vpd_hps
    end

    it 'una sala sin ajuste propio usa el de la industria' do
      sala = create(:sala, sede: sede, club: club, kind: 'vegetativo')

      expect(sala.leaf_temp_offset.to_f).to eq(-2.0)
    end
  end
end
