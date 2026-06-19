require 'rails_helper'

RSpec.describe AplicarPlanLoteService do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club) }
  let(:lote)  { create(:lote, club: club, sala: sala, start_date: 30.days.ago.to_date) }

  let(:plan) do
    PlanTrabajo.create!(
      club: club, creado_por: admin, titulo: 'Plan vege',
      estado: :publicado, periodo_tipo: :semanal,
      fecha_inicio: Date.today, fecha_fin: Date.today + 20.days
    )
  end

  before do
    # Tarea única, no recurrente, sin fecha específica → cae en la fecha de anclaje.
    PlanTarea.create!(plan_trabajo: plan, titulo: 'Riego', tipo: 'riego', prioridad: 'normal', es_recurrente: false)
  end

  context 'cuando se pasa una fecha_inicio en el pasado' do
    it 'genera la tarea anclada a esa fecha (no a start_date del lote)' do
      hace_dos_semanas = (Date.today - 14)

      creadas = described_class.new(
        lote: lote, plan: plan, ejecutado_por: admin,
        fecha_inicio: hace_dos_semanas.to_s
      ).aplicar!

      expect(creadas.size).to eq(1)
      expect(creadas.first.fecha_programada).to eq(hace_dos_semanas)
    end
  end

  context 'sin fecha_inicio explícita' do
    it 'usa el start_date del lote como ancla' do
      creadas = described_class.new(lote: lote, plan: plan, ejecutado_por: admin).aplicar!
      expect(creadas.first.fecha_programada).to eq(lote.start_date.to_date)
    end
  end
end
