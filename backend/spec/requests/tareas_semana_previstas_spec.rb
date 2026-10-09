require 'rails_helper'

# AC (9-oct-2026, Germán): el plan dice que el viernes 23 toca poda, pero la tarea recién se crea una
# semana antes y la semana del 23 se veía vacía. El calendario muestra lo que los planes tienen
# programado aunque todavía no sea una tarea, como previsto (sin acciones). Cuando se crea, deja
# de ser previsto y es la tarea: nunca las dos.
RSpec.describe 'GET /tareas/semana — lo previsto por los planes', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club) }
  let(:lote)  { create(:lote, club: club, sala: sala, start_date: hoy) }
  let(:hoy)   { Time.zone.today }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  let(:plantilla) do
    PlanTrabajo.create!(club: club, creado_por: admin, titulo: 'Autos', estado: :publicado, es_plantilla: true).tap do |p|
      PlanTarea.create!(plan_trabajo: p, titulo: 'Poda', tipo: 'poda', prioridad: 'normal', dia_relativo: 14)
    end
  end

  def aplicar = AplicarPlanLoteService.new(lote: lote, plan: plantilla, ejecutado_por: admin).aplicar!

  def semana(dia)
    get '/api/tareas/semana', params: { desde: dia.beginning_of_week(:monday).to_s }
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)['dias'].find { |d| d['fecha'] == dia.to_s }
  end

  before { sign_in_as(admin) }

  it 'la semana de la tarea muestra lo previsto, con su plan, el lote y cuándo se suma' do
    aplicar
    dia = semana(hoy + 14)

    expect(dia['tareas']).to be_empty
    expect(dia['previstas'].size).to eq(1)
    expect(dia['previstas'].first).to include('titulo' => 'Poda', 'prevista' => true,
                                              'aparece_el' => (hoy + 7).to_s)
    expect(dia['previstas'].first['lote']['codigo']).to eq(lote.codigo)
    expect(dia['previstas'].first['origen_plan']['titulo']).to eq('Autos')
  end

  it 'cuando se crea la tarea deja de ser prevista: nunca las dos' do
    aplicar
    Planes::Materializar.call(AplicacionPlan.last, hoy: hoy + 7)

    dia = semana(hoy + 14)
    expect(dia['tareas'].map { |t| t['titulo'] }).to eq(['Poda'])
    expect(dia['previstas']).to be_empty
  end

  it 'con el plan cancelado no hay nada previsto' do
    aplicacion, = aplicar
    aplicacion.update!(estado: 'cancelado')
    expect(semana(hoy + 14)['previstas']).to be_empty
  end

  it 'otra organización no ve lo previsto de esta' do
    aplicar
    otro = create(:club)
    sign_in_as(ActsAsTenant.with_tenant(otro) { create(:user, :admin, club: otro) })

    ActsAsTenant.with_tenant(otro) { expect(semana(hoy + 14)['previstas']).to be_empty }
  end
end
