require 'rails_helper'

# AC (7-oct-2026, Germán): al aplicar un plan, cada tarea va al día que dice el plan —contando desde
# el inicio del lote o desde la fecha que se elija— y aparece en las listas una semana antes de ese
# día, no todo el ciclo de una. Lo anterior al día en que se aplica no se crea (el plan arranca hoy).
RSpec.describe AplicarPlanLoteService do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club) }
  let(:lote)  { create(:lote, club: club, sala: sala, start_date: Time.zone.today) }
  let(:hoy)   { Time.zone.today }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  # Una plantilla: «Semana X · Día Y», sin fechas propias.
  let(:plantilla) do
    PlanTrabajo.create!(club: club, creado_por: admin, titulo: 'Vege', estado: :publicado, es_plantilla: true)
  end

  def tarea_del_plan(plan, dia, titulo = "Día #{dia}", tipo: 'riego')
    PlanTarea.create!(plan_trabajo: plan, titulo: titulo, tipo: tipo, prioridad: 'normal', dia_relativo: dia)
  end

  def aplicar(**opts)
    described_class.new(lote: lote, plan: plantilla, ejecutado_por: admin, **opts).aplicar!
  end

  it 'una plantilla se aplica desde el lote (antes fallaba) y cada tarea va a su día' do
    [0, 3, 21].each { |d| tarea_del_plan(plantilla, d) }

    previa = described_class.new(lote: lote, plan: plantilla, ejecutado_por: admin).preview
    expect(previa.map { |t| t[:fecha] }).to eq([hoy, hoy + 3, hoy + 21].map(&:to_s))
  end

  it 'crea ahora sólo lo de la semana: lo de dentro de tres semanas todavía no' do
    [0, 3, 21].each { |d| tarea_del_plan(plantilla, d) }

    _aplicacion, creadas = aplicar

    expect(creadas.map(&:fecha_programada)).to eq([hoy, hoy + 3])
    expect(club.tareas.count).to eq(2)
  end

  it 'lo que falta aparece cuando entra en la semana, una sola vez aunque el proceso corra dos veces' do
    tarea_del_plan(plantilla, 21)
    aplicacion, = aplicar

    travel_to(hoy + 14) do
      Planes::Materializar.call(aplicacion)
      Planes::Materializar.call(aplicacion)
    end

    expect(club.tareas.pluck(:fecha_programada)).to eq([hoy + 21])
  end

  it 'con el lote empezado hace un mes, el plan arranca hoy: no deja un mes de vencidas' do
    lote.update_columns(start_date: hoy - 30)
    [0, 10, 32].each { |d| tarea_del_plan(plantilla, d) }

    previa = described_class.new(lote: lote, plan: plantilla, ejecutado_por: admin).preview
    expect(previa.map { |t| t[:en_el_pasado] }).to eq([true, true, false])

    _aplicacion, creadas = aplicar
    expect(creadas.map(&:fecha_programada)).to eq([hoy + 2])
  end

  it 'se puede anclar en otra fecha que el inicio del lote' do
    tarea_del_plan(plantilla, 2)
    _aplicacion, creadas = aplicar(fecha_inicio: (hoy + 1).to_s)

    expect(creadas.map(&:fecha_programada)).to eq([hoy + 3])
  end

  it 'una tarea borrada o marcada «no se hizo» no vuelve a aparecer' do
    tarea_del_plan(plantilla, 0, 'Regar')
    tarea_del_plan(plantilla, 1, 'Podar', tipo: 'poda')
    aplicacion, creadas = aplicar
    creadas.first.destroy
    creadas.last.update_columns(estado: 'no_realizada')

    Planes::Materializar.call(aplicacion)

    expect(Tarea.with_deleted.where(aplicacion_plan_id: aplicacion.id).count).to eq(2)
  end

  it 'cancelado el plan, no crea lo que falta' do
    tarea_del_plan(plantilla, 21)
    aplicacion, = aplicar
    aplicacion.update!(estado: 'cancelado')

    travel_to(hoy + 14) { Planes::Materializar.call(aplicacion) }

    expect(club.tareas.count).to eq(0)
  end

  it 'con el lote terminado, no crea lo que falta' do
    tarea_del_plan(plantilla, 21)
    aplicacion, = aplicar
    lote.update_columns(estado: 'finalizado')

    travel_to(hoy + 14) { Planes::Materializar.call(aplicacion) }

    expect(club.tareas.count).to eq(0)
  end

  it 'lo que se le agrega a la plantilla después de aplicarla no cambia los lotes que ya la tenían' do
    tarea_del_plan(plantilla, 21)
    aplicacion, = aplicar
    travel_to(Time.current + 1.minute) { tarea_del_plan(plantilla, 22, 'Nueva') }

    travel_to(hoy + 16) { Planes::Materializar.call(aplicacion) }

    expect(club.tareas.pluck(:titulo)).to eq(['Día 21'])
  end

  describe 'un plan con fechas (no plantilla)' do
    let(:plan) do
      PlanTrabajo.create!(club: club, creado_por: admin, titulo: 'Semanal', estado: :publicado, periodo_tipo: :semanal,
                          fecha_inicio: hoy, fecha_fin: hoy + 20)
    end

    it 'lo que se repite ciertos días aparece día por día, una semana antes' do
      PlanTarea.create!(plan_trabajo: plan, titulo: 'Riego', tipo: 'riego', prioridad: 'normal',
                        es_recurrente: true, dias_semana: 'lun,jue')

      aplicacion, creadas = described_class.new(lote: lote, plan: plan, ejecutado_por: admin).aplicar!
      esperadas_hoy = (hoy..hoy + 7).select { |f| [1, 4].include?(f.wday) }
      expect(creadas.map(&:fecha_programada)).to eq(esperadas_hoy)

      travel_to(hoy + 20) { Planes::Materializar.call(aplicacion) }
      expect(club.tareas.count).to eq((hoy..hoy + 20).count { |f| [1, 4].include?(f.wday) })
    end
  end
end
