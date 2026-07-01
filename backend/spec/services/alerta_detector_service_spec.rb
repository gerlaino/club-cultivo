require 'rails_helper'

RSpec.describe AlertaDetectorService do
  let(:club)    { create(:club) }
  let(:sala)    { create(:sala, club: club) }
  let(:user)    { create(:user, club: club) }
  let(:lote)    { create(:lote, club: club, sala: sala, estado: 'vegetativo', start_date: 30.days.ago) }

  subject(:servicio) { described_class.new(club) }

  def detectar!
    servicio.detectar!
  end

  def alerta_del_tipo(tipo)
    club.alertas_internas.find_by(tipo: tipo)
  end

  # ── detectar_sin_registro ──────────────────────────────────────────────────

  describe '#detectar! — sin_registro_ambiental' do
    context 'cuando el lote lleva más días sin registro que el umbral del estadío' do
      before { lote }

      it 'crea una alerta de tipo sin_registro_ambiental' do
        expect { detectar! }.to change(club.alertas_internas, :count).by(1)
        alerta = alerta_del_tipo('sin_registro_ambiental')
        expect(alerta).to be_present
        expect(alerta.lote).to eq(lote)
        expect(alerta.severidad).to be_in(%w[warning error])
      end
    end

    context 'cuando hay un registro reciente dentro del umbral' do
      before { create(:registro_ambiental, lote: lote, user: user, registrado_en: 1.day.ago) }

      it 'no crea alerta' do
        expect { detectar! }.not_to change(club.alertas_internas, :count)
      end
    end

    context 'cuando el lote está finalizado' do
      let(:lote) { create(:lote, club: club, sala: sala, estado: 'finalizado') }

      it 'no procesa el lote' do
        expect { detectar! }.not_to change(club.alertas_internas, :count)
      end
    end
  end

  # ── detectar_rango_ambiental ───────────────────────────────────────────────

  describe '#detectar! — rango_ambiental' do
    before do
      create(:registro_ambiental, lote: lote, user: user, registrado_en: 1.hour.ago,  ph: 7.5)
      create(:registro_ambiental, lote: lote, user: user, registrado_en: 2.hours.ago, ph: 7.4)
      create(:registro_ambiental, lote: lote, user: user, registrado_en: 3.hours.ago, ph: 7.3)
    end

    it 'crea alerta ph_fuera_rango cuando 2+ de los últimos 3 registros están fuera de rango' do
      expect { detectar! }.to change(club.alertas_internas, :count).by_at_least(1)
      alerta = alerta_del_tipo('ph_fuera_rango')
      expect(alerta).to be_present
      expect(alerta.lote).to eq(lote)
    end

    context 'cuando solo 1 registro está fuera de rango' do
      before do
        club.alertas_internas.destroy_all
        lote.registros_ambientales.destroy_all
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 1.hour.ago,  ph: 7.5)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 2.hours.ago, ph: 6.0)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 3.hours.ago, ph: 6.1)
      end

      it 'no crea alerta ph_fuera_rango' do
        expect { detectar! }.not_to change { club.alertas_internas.where(tipo: 'ph_fuera_rango').count }
      end
    end
  end

  # ── detectar_cosecha_pendiente ─────────────────────────────────────────────

  describe '#detectar! — cosecha_pendiente' do
    context 'cuando el lote de floración ya superó sus semanas estimadas' do
      let(:lote) do
        create(:lote, club: club, sala: sala,
               estado: 'floracion',
               start_date: 70.days.ago,
               semanas_floracion: 8)
      end
      before { lote }

      it 'crea alerta cosecha_pendiente' do
        expect { detectar! }.to change { club.alertas_internas.where(tipo: 'cosecha_pendiente').count }.by(1)
        alerta = alerta_del_tipo('cosecha_pendiente')
        expect(alerta).to be_present
        expect(alerta.severidad).to eq('error')
      end
    end

    context 'cuando no se cumplieron las semanas de floración' do
      let(:lote) do
        create(:lote, club: club, sala: sala,
               estado: 'floracion',
               start_date: 20.days.ago,
               semanas_floracion: 8)
      end
      before { lote }

      it 'no crea alerta' do
        expect { detectar! }.not_to change { club.alertas_internas.where(tipo: 'cosecha_pendiente').count }
      end
    end
  end

  # ── detectar_tareas_vencidas ───────────────────────────────────────────────

  describe '#detectar! — tarea_vencida_cultivo' do
    let!(:tarea_vencida) do
      club.tareas.create!(
        titulo:           'Revisión plagas urgente',
        prioridad:        'urgente',
        estado:           'pendiente',
        tipo:             'revision_plagas',
        fecha_programada: 5.days.ago,
        lote:             lote,
        creada_por:       user
      )
    end

    it 'crea alerta tarea_vencida_cultivo con severidad error' do
      expect { detectar! }.to change(club.alertas_internas, :count).by_at_least(1)
      alerta = alerta_del_tipo('tarea_vencida_cultivo')
      expect(alerta).to be_present
      expect(alerta.severidad).to eq('error')
      expect(alerta.contexto['tarea_id']).to eq(tarea_vencida.id)
    end

    context 'con una tarea de prioridad normal' do
      let!(:tarea_vencida) do
        club.tareas.create!(
          titulo:           'Limpieza sala',
          prioridad:        'normal',
          estado:           'pendiente',
          tipo:             'limpieza',
          fecha_programada: 3.days.ago,
          lote:             lote,
          creada_por:       user
        )
      end

      it 'no crea alerta (solo alta/urgente disparan)' do
        expect { detectar! }.not_to change { club.alertas_internas.where(tipo: 'tarea_vencida_cultivo').count }
      end
    end
  end

  # ── setpoints del club ────────────────────────────────────────────────────

  describe '#detectar! — rango_ambiental con setpoints configurados' do
    context 'cuando el club tiene setpoint de temperatura para la fase' do
      before do
        # Setpoint custom: temperatura permitida 22-30 (más amplio que el default 20-28)
        SetpointFase.create!(
          club_id:      club.id,
          fase:         'vegetativo',
          tipo_lectura: 'temperatura',
          valor_min:    22,
          valor_max:    30,
        )
        # Registros con temperatura 29, 29, 29 → fuera del default (20-28) pero dentro del setpoint (22-30)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 1.hour.ago,  temperatura: 29)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 2.hours.ago, temperatura: 29)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 3.hours.ago, temperatura: 29)
      end

      it 'NO genera alerta porque los valores están dentro del setpoint del club' do
        expect { detectar! }.not_to change { club.alertas_internas.where(tipo: 'temperatura_fuera_rango').count }
      end
    end

    context 'cuando el club tiene setpoint más estricto que el default' do
      before do
        # Setpoint estricto: temperatura 24-25
        SetpointFase.create!(
          club_id:      club.id,
          fase:         'vegetativo',
          tipo_lectura: 'temperatura',
          valor_min:    24,
          valor_max:    25,
        )
        # Temperatura 22 → dentro del default (20-28) pero fuera del setpoint (24-25)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 1.hour.ago,  temperatura: 22)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 2.hours.ago, temperatura: 22)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 3.hours.ago, temperatura: 22)
      end

      it 'SÍ genera alerta porque los valores están fuera del setpoint del club' do
        expect { detectar! }.to change { club.alertas_internas.where(tipo: 'temperatura_fuera_rango').count }.by(1)
      end
    end

    context 'cuando no hay setpoints configurados' do
      before do
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 1.hour.ago,  ph: 7.5)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 2.hours.ago, ph: 7.4)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 3.hours.ago, ph: 7.3)
      end

      it 'usa los RANGOS default y genera alerta' do
        expect { detectar! }.to change { club.alertas_internas.where(tipo: 'ph_fuera_rango').count }.by(1)
      end
    end

    context 'setpoint específico de cepa tiene prioridad sobre genérico' do
      let(:genetica) { create(:genetica, club: club) }
      let(:lote) do
        create(:lote, club: club, sala: sala, estado: 'vegetativo',
               start_date: 30.days.ago, genetica: genetica)
      end

      before do
        # Setpoint genérico (sin cepa): 20-28
        SetpointFase.create!(club_id: club.id, fase: 'vegetativo', tipo_lectura: 'temperatura',
                             valor_min: 20, valor_max: 28, genetica_id: nil)
        # Setpoint específico para la cepa: 26-30
        SetpointFase.create!(club_id: club.id, fase: 'vegetativo', tipo_lectura: 'temperatura',
                             valor_min: 26, valor_max: 30, genetica_id: genetica.id)
        # Temperatura 25 → dentro del genérico pero fuera del específico
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 1.hour.ago,  temperatura: 25)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 2.hours.ago, temperatura: 25)
        create(:registro_ambiental, lote: lote, user: user, registrado_en: 3.hours.ago, temperatura: 25)
      end

      it 'usa el setpoint de la cepa y genera alerta' do
        expect { detectar! }.to change { club.alertas_internas.where(tipo: 'temperatura_fuera_rango').count }.by(1)
      end
    end
  end

  # ── paraguas vegetativo (semilla/esqueje usan rangos de vegetativo) ─────────

  describe '#detectar! — rango_ambiental para semilla/esqueje (paraguas vegetativo)' do
    %w[semilla esqueje].each do |estado_origen|
      context "cuando el lote está en #{estado_origen}" do
        let(:lote) { create(:lote, club: club, sala: sala, estado: estado_origen, start_date: 10.days.ago) }

        before do
          # ph 7.3-7.5 → fuera del rango de vegetativo (5.8-6.2). Antes del paraguas,
          # semilla/esqueje no tenían fase de setpoint ni RANGOS → no se chequeaban.
          create(:registro_ambiental, lote: lote, user: user, registrado_en: 1.hour.ago,  ph: 7.5)
          create(:registro_ambiental, lote: lote, user: user, registrado_en: 2.hours.ago, ph: 7.4)
          create(:registro_ambiental, lote: lote, user: user, registrado_en: 3.hours.ago, ph: 7.3)
        end

        it 'usa los rangos de vegetativo y genera alerta ph_fuera_rango' do
          expect { detectar! }.to change { club.alertas_internas.where(tipo: 'ph_fuera_rango').count }.by(1)
        end
      end
    end
  end

  # ── deduplicación ─────────────────────────────────────────────────────────

  describe 'deduplicación' do
    it 'no crea una segunda alerta si ya existe una del mismo tipo en las últimas 20 horas' do
      club.alertas_internas.create!(
        tipo:             'sin_registro_ambiental',
        lote:             lote,
        severidad:        'warning',
        mensaje:          'ya existe',
        destinada_a_role: 'admin',
        creada_por:       user
      )

      expect { detectar! }.not_to change { club.alertas_internas.where(tipo: 'sin_registro_ambiental', lote: lote).count }
    end

    it 'crea nueva alerta si la anterior tiene más de 20 horas' do
      club.alertas_internas.create!(
        tipo:             'sin_registro_ambiental',
        lote:             lote,
        severidad:        'warning',
        mensaje:          'vieja',
        destinada_a_role: 'admin',
        creada_por:       user,
        created_at:       21.hours.ago
      )

      expect { detectar! }.to change { club.alertas_internas.where(tipo: 'sin_registro_ambiental', lote: lote).count }.by(1)
    end
  end
end
