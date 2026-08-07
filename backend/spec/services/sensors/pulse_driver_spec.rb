require 'rails_helper'

# `pulse` estaba en Dispositivo::TIPOS pero sin driver propio: caía en el genérico, que sólo
# entiende claves en castellano. Un Pulse conectado no registraba NADA y el club se quedaba
# mirando una sala sin lecturas sin saber por qué.
RSpec.describe Sensors::PulseDriver do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
  let(:sala)  { create(:sala, sede: sede, club: club, kind: 'vegetativo') }
  let(:dispositivo) { create(:dispositivo, club: club, sala: sala, tipo: 'pulse') }

  subject(:driver) { described_class.new(dispositivo) }

  def tipos(lecturas) = lecturas.map { |l| l[:tipo] }
  def valor(lecturas, tipo) = lecturas.find { |l| l[:tipo] == tipo }&.dig(:valor)

  it 'lee temperatura y humedad del payload plano' do
    l = driver.lecturas_desde('temperature' => 24.5, 'humidity' => 62)

    expect(valor(l, 'temperatura')).to eq(24.5)
    expect(valor(l, 'humedad')).to eq(62.0)
  end

  it 'lee el payload anidado en data' do
    l = driver.lecturas_desde('data' => { 'temperatureC' => 21.0, 'humidityRh' => 55 })

    expect(valor(l, 'temperatura')).to eq(21.0)
    expect(valor(l, 'humedad')).to eq(55.0)
  end

  # El VPD del equipo se ignora: la app lo calcula sola desde temperatura y humedad, con la
  # misma fórmula para todos los sensores. Dos VPD para la misma sala es lo que hace
  # desconfiar del dato.
  it 'ignora el VPD que manda el equipo y deja que lo calcule la app' do
    l = driver.lecturas_desde('temperature' => 24, 'humidity' => 60, 'vpd' => 9.99)

    expect(tipos(l)).not_to include('vpd')
  end

  it 'el VPD aparece igual, calculado desde temperatura y humedad' do
    driver.persist!('temperature' => 24, 'humidity' => 60)

    vpd = LecturaAmbiental.find_by(sala_id: sala.id, tipo: 'vpd')
    expect(vpd).to be_present
    expect(vpd.valor.to_f).to be > 0
  end

  it 'ignora los campos que el equipo no manda' do
    l = driver.lecturas_desde('temperature' => 20)

    expect(tipos(l)).to eq(['temperatura'])
  end

  it 'no confunde un cero con un campo ausente' do
    l = driver.lecturas_desde('temperature' => 0, 'co2' => 0)

    expect(valor(l, 'temperatura')).to eq(0.0)
    expect(valor(l, 'co2')).to eq(0.0)
  end

  describe 'la marca de tiempo' do
    it 'entiende epoch en segundos' do
      l = driver.lecturas_desde('temperature' => 20, 'timestamp' => 1_754_000_000)

      expect(l.first[:medido_at].to_i).to eq(1_754_000_000)
    end

    # Mandar milisegundos y fecharlos como segundos daba el año 57.000.
    it 'entiende epoch en milisegundos' do
      l = driver.lecturas_desde('temperature' => 20, 'timestamp' => 1_754_000_000_000)

      expect(l.first[:medido_at].year).to eq(2025)
    end

    it 'entiende una fecha ISO' do
      l = driver.lecturas_desde('temperature' => 20, 'createdAt' => '2026-08-07T12:00:00Z')

      expect(l.first[:medido_at].year).to eq(2026)
    end

    # Sin fecha, la lectura se guarda igual: descartarla sería perder el dato.
    it 'sin marca de tiempo usa el momento en que llegó' do
      l = driver.lecturas_desde('temperature' => 20)

      expect(l.first[:medido_at]).to be_within(5.seconds).of(Time.current)
    end

    it 'una fecha basura no rompe la lectura' do
      l = driver.lecturas_desde('temperature' => 20, 'timestamp' => 'ayer a la tarde')

      expect(l.first[:medido_at]).to be_within(5.seconds).of(Time.current)
    end
  end

  it 'guarda las lecturas contra la sala del dispositivo' do
    driver.persist!('temperature' => 23.4, 'humidity' => 58)

    # El vpd lo agrega la app a partir de los otros dos.
    expect(LecturaAmbiental.where(sala_id: sala.id).pluck(:tipo)).to include('temperatura', 'humedad')
  end

  # El webhook resuelve el driver por convención de nombre: sin esto, `pulse` volvería a caer
  # en el genérico sin que nadie se entere.
  it 'el webhook lo encuentra por el tipo del dispositivo' do
    expect("Sensors::#{'pulse'.camelize}Driver".constantize).to eq(described_class)
  end
end
