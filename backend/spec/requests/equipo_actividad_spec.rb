require 'rails_helper'

# AC (Germán, 12-oct-2026, lienzo de Equipo aprobado): la lista de Equipo dice, por persona, qué
# hizo hoy, sus horas del mes, qué tiene pendiente y su último acceso; arriba, el cupo del plan
# por rol. Lo de hoy dice lo mismo que el panel de conducción.
RSpec.describe 'Equipo — actividad y cupo', type: :request do
  let(:club)  { create(:club, plan: 'basico', features: { 'produccion_dispensa' => true, 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'mixta') }
  let!(:lucia) { create(:user, :dispensador, club: club, first_name: 'Lucía', visto_at: 3.minutes.ago) }
  let!(:sofia) { create(:user, :cultivador, club: club, first_name: 'Sofía') }

  def json = JSON.parse(response.body)
  def actividad = (get('/api/usuarios/actividad') && json)

  before { sign_in_as(admin) }

  it 'todas las personas del equipo, también las que no hicieron nada hoy' do
    p = actividad['personas']
    expect(p.keys.map(&:to_i)).to include(admin.id, lucia.id, sofia.id)
    expect(p[sofia.id.to_s]).to include('actividad' => [], 'alertas' => [])
  end

  it 'qué hizo hoy y qué tiene pendiente, con el mismo texto que el panel de conducción' do
    ActsAsTenant.with_tenant(club) do
      Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: lucia, efectivo_contado_ars: 0)
      create(:tarea, club: club, asignada_a: sofia, estado: 'pendiente', fecha_programada: Time.zone.today - 3)
    end
    p = actividad['personas']
    expect(p[lucia.id.to_s]['actividad'].first).to start_with('caja abierta desde las')
    expect(p[sofia.id.to_s]['alertas']).to eq(['1 tarea vencida'])

    get '/api/panel_conduccion'
    eq = json['equipo'].index_by { |x| x['id'] }
    expect(eq[lucia.id]['actividad']).to eq(p[lucia.id.to_s]['actividad'])
    expect(eq[sofia.id]['alertas']).to eq(p[sofia.id.to_s]['alertas'])
  end

  it 'las horas del mes y el último acceso' do
    ActsAsTenant.with_tenant(club) do
      JornadaLaboral.create!(club: club, user: lucia, fecha: Time.zone.today, hora_entrada: '09:00', hora_salida: '13:30', estado: 'enviada')
    end
    l = actividad['personas'][lucia.id.to_s]
    expect(l['horas_mes']).to eq(4.5)
    expect(Time.zone.parse(l['ultimo_acceso'])).to be_within(1.second).of(lucia.reload.visto_at)
    expect(actividad['personas'][sofia.id.to_s]['horas_mes']).to be_nil
  end

  it 'las sedes de cada persona; sin sedes, ninguna (ve toda la organización)' do
    UserSede.create!(user: lucia, sede: sede)
    p = actividad['personas']
    expect(p[lucia.id.to_s]['sedes']).to eq([sede.nombre])
    expect(p[sofia.id.to_s]['sedes']).to eq([])
  end

  it 'el cupo por rol: cuántos hay y el tope del plan; administración no tiene tope' do
    cupo = actividad['cupo']
    expect(cupo['plan']).to eq('Hasta 50 pacientes')
    disp = cupo['por_rol'].find { |r| r['rol'] == 'dispensador' }
    expect(disp).to include('usados' => 1, 'tope' => 2)
    expect(cupo['por_rol'].map { |r| r['rol'] }).not_to include('admin')
  end

  it 'sólo el administrador la ve' do
    sign_in_as(lucia)
    get '/api/usuarios/actividad'
    expect(response).to have_http_status(:forbidden)
  end

  it 'la gente de otra organización no aparece' do
    otro = create(:user, :dispensador, club: create(:club))
    expect(actividad['personas'].keys.map(&:to_i)).not_to include(otro.id)
  end
end
