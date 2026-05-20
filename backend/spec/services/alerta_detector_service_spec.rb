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
