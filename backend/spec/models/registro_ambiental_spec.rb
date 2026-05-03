require 'rails_helper'

RSpec.describe RegistroAmbiental, type: :model do
  describe 'propagación a LecturaAmbiental' do
    let(:club) { create(:club) }
    let(:sala) { create(:sala, club: club) }
    let(:user) { create(:user, club: club) }
    let(:lote) { create(:lote, club: club, sala: sala) }

    context 'al crear con temperatura y humedad' do
      subject(:registro) do
        create(:registro_ambiental,
          lote: lote, user: user, club: club,
          temperatura: 26.0, humedad: 55.0,
          co2: nil, ppfd: nil, ph: nil, ph_runoff: nil, temperatura_sustrato: nil
        )
      end

      it 'crea LecturaAmbiental para temperatura' do
        expect { registro }.to change(LecturaAmbiental, :count).by(3) # temp + humedad + vpd calculado
      end

      it 'propaga el valor de temperatura correctamente' do
        registro
        lectura = LecturaAmbiental.find_by(
          origen_record_type: 'RegistroAmbiental',
          origen_record_id:   registro.id,
          tipo:               'temperatura'
        )
        expect(lectura).to be_present
        expect(lectura.valor).to eq(26.0)
        expect(lectura.unidad).to eq('°C')
        expect(lectura.fuente).to eq('manual')
        expect(lectura.sala_id).to eq(sala.id)
        expect(lectura.club_id).to eq(club.id)
      end

      it 'propaga el VPD calculado' do
        registro
        lectura = LecturaAmbiental.find_by(
          origen_record_type: 'RegistroAmbiental',
          origen_record_id:   registro.id,
          tipo:               'vpd'
        )
        expect(lectura).to be_present
        expect(lectura.valor).to be > 0
      end
    end

    context 'al crear (encola EvaluarReglasJob)' do
      it 'encola EvaluarReglasJob con el sala_id correcto' do
        expect(EvaluarReglasJob).to receive(:perform_later).with(sala.id)
        create(:registro_ambiental, lote: lote, user: user, club: club,
          temperatura: 25.0, humedad: 60.0)
      end
    end

    context 'al crear con todos los campos métricos (caso de prueba completo)' do
      subject(:registro) do
        create(:registro_ambiental,
          lote: lote, user: user, club: club,
          temperatura: 23.5, humedad: 60.0,
          ec: 1.8, ec_runoff: 2.1, ph_runoff: 6.5, ppfd: 800,
          co2: nil, ph: nil, temperatura_sustrato: nil
        )
      end

      it 'propaga los 7 tipos métricos' do
        registro
        tipos = LecturaAmbiental.where(
          origen_record_type: 'RegistroAmbiental',
          origen_record_id:   registro.id
        ).pluck(:tipo)
        expect(tipos).to match_array(%w[temperatura humedad vpd ec ec_runoff ph_runoff ppfd])
      end

      it 'ec tiene unidad mS/cm' do
        registro
        lectura = LecturaAmbiental.find_by(
          origen_record_type: 'RegistroAmbiental',
          origen_record_id:   registro.id,
          tipo:               'ec'
        )
        expect(lectura.valor).to eq(1.8)
        expect(lectura.unidad).to eq('mS/cm')
      end

      it 'ec_runoff se propaga' do
        registro
        lectura = LecturaAmbiental.find_by(
          origen_record_type: 'RegistroAmbiental',
          origen_record_id:   registro.id,
          tipo:               'ec_runoff'
        )
        expect(lectura.valor).to eq(2.1)
      end
    end

    context 'al actualizar (idempotencia)' do
      let!(:registro) do
        create(:registro_ambiental,
          lote: lote, user: user, club: club,
          temperatura: 24.0, humedad: 60.0
        )
      end

      it 'no duplica LecturasAmbientales al hacer update' do
        expect {
          registro.update!(temperatura: 25.0)
        }.not_to change(LecturaAmbiental, :count)

        lectura = LecturaAmbiental.find_by(
          origen_record_type: 'RegistroAmbiental',
          origen_record_id:   registro.id,
          tipo:               'temperatura'
        )
        expect(lectura.valor).to eq(25.0)
      end
    end
  end

  describe 'cálculo de VPD' do
    let(:club) { create(:club) }
    let(:sala) { create(:sala, club: club) }
    let(:user) { create(:user, club: club) }
    let(:lote) { create(:lote, club: club, sala: sala) }

    it 'calcula VPD automáticamente al guardar' do
      registro = create(:registro_ambiental,
        lote: lote, user: user, club: club,
        temperatura: 25.0, humedad: 60.0)
      expect(registro.vpd).to be_present
      expect(registro.vpd).to be_within(0.01).of(1.265)
    end

    it 'no calcula VPD si falta temperatura o humedad' do
      registro = build(:registro_ambiental,
        lote: lote, user: user, club: club,
        temperatura: nil, humedad: nil)
      registro.save(validate: false)
      expect(registro.vpd).to be_nil
    end
  end
end
