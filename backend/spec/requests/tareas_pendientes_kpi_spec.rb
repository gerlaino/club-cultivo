require 'rails_helper'

RSpec.describe 'KPI de tareas pendientes (vencidas + hoy, no futuras)', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def tarea(fecha:, estado: 'pendiente')
    Tarea.create!(club: club, creada_por: admin, titulo: "t-#{SecureRandom.hex(2)}",
                  estado: estado, fecha_programada: fecha)
  end

  before { sign_in_as(admin) }

  it 'cuenta solo vencidas + de hoy (no futuras) en stats.pendientes' do
    tarea(fecha: Date.current - 2)   # vencida
    tarea(fecha: Date.current)       # hoy
    tarea(fecha: Date.current + 3)   # futura → NO cuenta
    tarea(fecha: Date.current, estado: 'completada') # hecha → NO cuenta

    get '/api/tareas/dashboard', as: :json

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig('stats', 'pendientes')).to eq(2)
  end

  it 'incluye las tareas sin fecha como pendientes del día' do
    tarea(fecha: nil)
    get '/api/tareas/dashboard', as: :json
    expect(JSON.parse(response.body).dig('stats', 'pendientes')).to eq(1)
  end

  # El listado accionable de /tareas: el KPI y la lista tienen que hablar del mismo conjunto.
  it 'devuelve el listado de pendientes con el mismo scope que el KPI' do
    venc = tarea(fecha: Date.current - 2)
    hoy  = tarea(fecha: Date.current)
    sin  = tarea(fecha: nil)
    futura = tarea(fecha: Date.current + 3)
    hecha  = tarea(fecha: Date.current, estado: 'completada')

    get '/api/tareas/dashboard', as: :json
    body = JSON.parse(response.body)
    ids  = body['pendientes'].map { |t| t['id'] }

    expect(ids).to contain_exactly(venc.id, hoy.id, sin.id)
    expect(ids).not_to include(futura.id, hecha.id)
    expect(ids.length).to eq(body.dig('stats', 'pendientes'))
  end

  it 'ordena el listado por fecha (lo más viejo primero) y deja las sin fecha al final' do
    vieja  = tarea(fecha: Date.current - 5)
    ayer   = tarea(fecha: Date.current - 1)
    de_hoy = tarea(fecha: Date.current)
    sin    = tarea(fecha: nil)

    get '/api/tareas/dashboard', as: :json

    expect(JSON.parse(response.body)['pendientes'].map { |t| t['id'] })
      .to eq([vieja.id, ayer.id, de_hoy.id, sin.id])
  end

  it 'un no-admin solo ve sus pendientes' do
    cult = create(:user, :cultivador, club: club)
    mia  = Tarea.create!(club: club, creada_por: admin, titulo: 'mía', fecha_programada: Date.current,
                         asignada_a: cult)
    tarea(fecha: Date.current) # sin asignar → no es suya

    sign_in_as(cult)
    get '/api/tareas/dashboard', as: :json

    expect(JSON.parse(response.body)['pendientes'].map { |t| t['id'] }).to eq([mia.id])
  end
end

RSpec.describe 'DELETE /api/tareas/:id (tareas completadas)', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def tarea_completada
    Tarea.create!(club: club, creada_por: admin, titulo: 'hecha', estado: 'completada',
                  fecha_completada: Time.current)
  end

  it 'un admin puede borrar una tarea completada' do
    t = tarea_completada
    sign_in_as(admin)
    delete "/api/tareas/#{t.id}", as: :json
    expect(response).to have_http_status(:no_content)
    expect(Tarea.exists?(t.id)).to be(false)
  end

  it 'un cultivador NO puede borrar una tarea completada' do
    cult = create(:user, :cultivador, club: club)
    t = tarea_completada
    sign_in_as(cult)
    delete "/api/tareas/#{t.id}", as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Tarea.exists?(t.id)).to be(true)
  end
end
