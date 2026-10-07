require 'rails_helper'

# AC (7-oct-2026, Germán): así como se marca que una tarea se hizo, se marca que NO se hizo, con un
# motivo si se quiere. Queda registrado (no es «cancelada», que es «ya no va»).
RSpec.describe 'POST /tareas/:id/no_realizada', type: :request do
  let(:club)       { create(:club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def tarea(**attrs) = create(:tarea, club: club, creada_por: admin, **attrs)

  it 'la marca, con el motivo y cuándo' do
    t = tarea
    sign_in_as(admin)

    post "/api/tareas/#{t.id}/no_realizada", params: { motivo: 'faltó el producto' }, as: :json

    expect(response).to have_http_status(:ok)
    expect(t.reload).to have_attributes(estado: 'no_realizada', notas_completado: 'faltó el producto')
    expect(t.fecha_completada).to be_present
  end

  it 'sin motivo también' do
    t = tarea
    sign_in_as(admin)
    post "/api/tareas/#{t.id}/no_realizada", as: :json
    expect(t.reload.estado).to eq('no_realizada')
  end

  it 'sale de las pendientes' do
    t = tarea
    sign_in_as(admin)
    post "/api/tareas/#{t.id}/no_realizada", as: :json

    expect(Tarea.activas).not_to include(t)
    expect(Tarea.pendientes_al_dia).not_to include(t)
  end

  it 'una de más adelante todavía no se puede marcar' do
    t = tarea(fecha_programada: Time.zone.today + 2)
    sign_in_as(admin)
    post "/api/tareas/#{t.id}/no_realizada", as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(t.reload.estado).to eq('pendiente')
  end

  it 'una ya cerrada no se vuelve a cerrar' do
    t = tarea(estado: 'completada')
    sign_in_as(admin)
    post "/api/tareas/#{t.id}/no_realizada", as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(t.reload.estado).to eq('completada')
  end

  it 'una no hecha no se puede completar después' do
    t = tarea
    t.marcar_no_realizada!
    sign_in_as(admin)
    post "/api/tareas/#{t.id}/completar", params: { horas_reales: 1 }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  # Las mismas reglas que completar: el cultivador gestiona tareas.
  it 'el cultivador la puede marcar, como puede completarla' do
    suya = tarea(asignada_a: cultivador)
    sign_in_as(cultivador)

    post "/api/tareas/#{suya.id}/no_realizada", as: :json

    expect(response).to have_http_status(:ok)
    expect(suya.reload.estado).to eq('no_realizada')
  end

  it 'no toca tareas de otra organización' do
    otra = create(:club)
    ajena = ActsAsTenant.with_tenant(otra) { create(:tarea, club: otra) }
    sign_in_as(admin)

    post "/api/tareas/#{ajena.id}/no_realizada", as: :json

    expect(response.status).to be_in([403, 404])
    expect(ajena.reload.estado).to eq('pendiente')
  end
end

# Una tarea nueva tiene día; las viejas sin fecha siguen pudiendo cerrarse.
RSpec.describe 'Tarea: fecha obligatoria al crear', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  it 'sin fecha no se crea, y lo dice' do
    sign_in_as(admin)
    post '/api/tareas', params: { tarea: { titulo: 'Regar', tipo: 'riego', prioridad: 'normal' } }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('para qué día')
  end

  it 'una que se repite todos los viernes arranca un día y se crea' do
    sign_in_as(admin)
    viernes = Time.zone.today + ((5 - Time.zone.today.wday) % 7)
    post '/api/tareas', params: { tarea: { titulo: 'Revisar', tipo: 'inspeccion', prioridad: 'normal', fecha_programada: viernes,
                                           recurrente: true, frecuencia: 'semanal', recurrencia_veces: 3 } }, as: :json

    expect(response).to have_http_status(:created), response.body
    expect(club.tareas.pluck(:fecha_programada).sort).to eq([viernes, viernes + 7, viernes + 14])
  end
end

# Las otras puertas que aplican un plan usan la misma cuenta.
RSpec.describe 'Planes: publicar y aplicar desde la pantalla de planes', type: :request do
  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, start_date: Time.zone.today) }
  let(:hoy)   { Time.zone.today }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }
  before { sign_in_as(admin) }

  def plantilla_con(*dias)
    p = PlanTrabajo.create!(club: club, creado_por: admin, titulo: 'Vege', es_plantilla: true)
    dias.each { |d| PlanTarea.create!(plan_trabajo: p, titulo: "Día #{d}", tipo: 'riego', prioridad: 'normal', dia_relativo: d) }
    p
  end

  # De acá salían las pendientes sin fecha: publicar una plantilla creaba sus tareas con la fecha
  # de inicio del plan, que una plantilla no tiene.
  it 'publicar una plantilla no crea tareas' do
    p = plantilla_con(0, 7)
    post "/api/plan_trabajos/#{p.id}/publicar", as: :json

    expect(response).to have_http_status(:ok), response.body
    expect(club.tareas.count).to eq(0)
  end

  it 'aplicar una plantilla a un lote desde la pantalla de planes: lo de la semana ya, el resto después' do
    p = plantilla_con(0, 3, 20)
    post '/api/aplicacion_planes', params: { plan_trabajo_id: p.id, fecha_inicio: hoy, objetivo_tipo: 'Lote', objetivo_id: lote.id }, as: :json

    expect(response).to have_http_status(:created), response.body
    expect(club.tareas.pluck(:fecha_programada).sort).to eq([hoy, hoy + 3])
    expect(response.parsed_body['proximas'].map { |t| t['fecha_programada'] }).to eq([(hoy + 20).to_s])
  end

  it 'un lote de otra organización no se puede usar de objetivo' do
    p = plantilla_con(0)
    otra = create(:club)
    ajeno = ActsAsTenant.with_tenant(otra) { create(:lote, club: otra, sala: create(:sala, club: otra)) }

    post '/api/aplicacion_planes', params: { plan_trabajo_id: p.id, fecha_inicio: hoy, objetivo_tipo: 'Lote', objetivo_id: ajeno.id }, as: :json

    expect(response).not_to have_http_status(:created)
    expect(Tarea.unscoped.where(lote_id: ajeno.id).count).to eq(0)
  end

  it 'el cálculo previo dice qué tareas va a tener y cuándo aparece cada una, sin crear nada' do
    p = plantilla_con(0, 20)
    get '/api/aplicacion_planes/preview', params: { plan_trabajo_id: p.id, fecha_inicio: hoy, objetivo_tipo: 'Lote', objetivo_id: lote.id }

    expect(response).to have_http_status(:ok)
    t = response.parsed_body['tareas']
    expect(t.map { |x| x['fecha'] }).to eq([hoy.to_s, (hoy + 20).to_s])
    expect(t.map { |x| x['aparece_el'] }).to eq([hoy.to_s, (hoy + 13).to_s])
    expect(club.tareas.count).to eq(0)
  end

  it 'el proceso diario crea lo que entra en la semana, para todas las organizaciones' do
    p = plantilla_con(10)
    post '/api/aplicacion_planes', params: { plan_trabajo_id: p.id, fecha_inicio: hoy, objetivo_tipo: 'Lote', objetivo_id: lote.id }, as: :json
    expect(club.tareas.count).to eq(0)

    travel_to(hoy + 4) { MaterializarTareasDePlanesJob.new.perform }

    expect(club.tareas.pluck(:fecha_programada)).to eq([hoy + 10])
  end
end
