require 'rails_helper'

# AC (Germán): "el KPI de la sala me toma el dato de las incubadoras en lugar del registro de la
# sala; habría que agregar el KPI que muestre temp y hum de incubadora/bandeja cuando hay".
#
# El registro ambiental cuelga del LOTE y se propaga a `lecturas_ambientales` con el `sala_id`.
# Un lote enraizando se mide adentro del propagador —28 °C y 90 % es su objetivo— y eso salía
# publicado como el aire del cuarto.
RSpec.describe 'Ambiente de la sala vs. de la incubadora', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'mixta') }

  # El del cuarto: 24 °C / 55 %. El del domo: 28 °C / 90 %.
  let!(:lote_vege)      { create(:lote, club: club, sala: sala, estado: 'vegetativo') }
  let!(:lote_enraizado) { create(:lote, club: club, sala: sala, estado: 'enraizado') }

  def registrar(lote, temp:, hum:)
    create(:registro_ambiental, club: club, lote: lote, user: admin,
                                temperatura: temp, humedad: hum, registrado_en: Time.current)
  end

  def detalle
    get "/salas/#{sala.id}", headers: auth_headers
    JSON.parse(response.body)
  end

  before { sign_in_as(admin) }

  describe 'el KPI de la sala' do
    it 'muestra el aire del cuarto y NO el del propagador' do
      registrar(lote_vege,      temp: 24.0, hum: 55)
      registrar(lote_enraizado, temp: 28.0, hum: 90)

      amb = detalle['ambiente_actual']
      expect(amb['temperatura']).to eq(24.0)
      expect(amb['humedad']).to eq(55.0)
    end

    # El caso que rompía: si el único registro del día es de un lote enraizando, la sala se
    # quedaba con el clima del domo. Ahora dice "sin datos", que es la verdad.
    it 'queda sin dato si lo único que se midió fue la incubadora' do
      registrar(lote_enraizado, temp: 28.0, hum: 90)

      expect(detalle['ambiente_actual']).to be_nil
    end
  end

  describe 'el KPI de la incubadora' do
    it 'aparece cuando hay algo enraizando, con su temp y humedad' do
      registrar(lote_enraizado, temp: 28.0, hum: 90)

      inc = detalle['ambiente_incubadora']
      expect(inc['temperatura']).to eq(28.0)
      expect(inc['humedad']).to eq(90.0)
      expect(inc['punto']).to eq('incubadora')
    end

    it 'no aparece si no hay nada enraizando' do
      registrar(lote_vege, temp: 24.0, hum: 55)

      expect(detalle['ambiente_incubadora']).to be_nil
    end
  end

  # El punto no se pide en el formulario: se deriva de dónde ESTÁ la planta.
  describe 'de dónde sale el punto de medición' do
    it 'un registro de un lote enraizando es de la incubadora' do
      expect(registrar(lote_enraizado, temp: 28.0, hum: 90).punto_medicion).to eq('incubadora')
    end

    it 'y el de cualquier otro es del cuarto' do
      expect(registrar(lote_vege, temp: 24.0, hum: 55).punto_medicion).to eq('sala')
    end

    it 'la lectura propagada se lleva el punto: si se pierde ahí, el KPI vuelve a mezclar' do
      registrar(lote_enraizado, temp: 28.0, hum: 90)

      expect(LecturaAmbiental.where(sala_id: sala.id).pluck(:punto_medicion).uniq).to eq(['incubadora'])
    end
  end

  # Adentro del domo el 90 % de humedad es el objetivo; en el cuarto sería una emergencia.
  describe 'las reglas ambientales de la sala' do
    it 'no se disparan con una lectura de la incubadora' do
      regla = create(:regla_ambiental, club: club, sala: sala, tipo_lectura: 'humedad',
                                       condicion: 'gt', umbral_a: 70, duracion_minutos: 60,
                                       activa: true)

      expect {
        registrar(lote_enraizado, temp: 28.0, hum: 90)
        Ambiente::EvaluadorReglas.call(sala)
      }.not_to change { Alerta.where(regla_id: regla.id).count }
    end

    it 'pero sí con una del cuarto' do
      regla = create(:regla_ambiental, club: club, sala: sala, tipo_lectura: 'humedad',
                                       condicion: 'gt', umbral_a: 70, duracion_minutos: 60,
                                       activa: true)

      expect {
        registrar(lote_vege, temp: 24.0, hum: 90)
        Ambiente::EvaluadorReglas.call(sala)
      }.to change { Alerta.where(regla_id: regla.id).count }.by(1)
    end
  end
end
