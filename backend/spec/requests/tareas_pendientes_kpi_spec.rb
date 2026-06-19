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
