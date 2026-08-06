require 'rails_helper'

# AC: una PlanTarea se materializa como Tarea al aplicar el plan. Si los catálogos divergen,
# o no se puede guardar el plan (422) o explota al aplicarlo. Este spec ata las dos listas.
RSpec.describe PlanTarea, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:plan)  { club.plan_trabajos.create!(titulo: 'Plan', creado_por: admin,
                              fecha_inicio: Date.today, fecha_fin: Date.today + 7) }

  it 'acepta exactamente los mismos tipos que Tarea' do
    expect(described_class::TIPOS).to eq(Tarea::TIPOS)
  end

  it 'acepta exactamente las mismas prioridades que Tarea' do
    expect(described_class::PRIORIDADES).to eq(Tarea::PRIORIDADES)
  end

  # Los cinco que el formulario ofrecía y el modelo rechazaba con un 422 mudo.
  %w[nutricion defoliacion scrog_lst ajuste_luz revision_plagas].each do |tipo|
    it "guarda una tarea de tipo #{tipo}" do
      pt = plan.plan_tareas.build(tipo: tipo, titulo: "Tarea #{tipo}", prioridad: 'normal')

      expect(pt).to be_valid, -> { pt.errors.full_messages.join(', ') }
      expect { pt.save! }.not_to raise_error
    end
  end

  it 'sigue rechazando un tipo que no existe' do
    pt = plan.plan_tareas.build(tipo: 'inventado', titulo: 'X', prioridad: 'normal')

    expect(pt).not_to be_valid
    expect(pt.errors[:tipo]).to be_present
  end
end
