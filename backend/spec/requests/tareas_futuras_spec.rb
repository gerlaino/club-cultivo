require 'rails_helper'

# AC: una tarea programada para más adelante NO se puede dar por hecha, por ningún camino.
#
# El bug: la regla vivía sólo en la UI y cada pantalla traía su propio criterio — la semana del
# teléfono la bloqueaba, y el bloque de tareas del lote dejaba marcar una futura tocándola a
# mano. El backend no validaba nada, así que la regla se podía saltear.
#
# Flujo correcto cuando el trabajo se adelanta: se carga una tarea de HOY con lo que se hizo, y
# la programada se cancela cuando llegue su día, con la observación.
RSpec.describe 'Completar tareas programadas a futuro', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:hoy)   { Time.zone.today }

  # No hay factory de Tarea; mismo patrón que tareas_pendientes_kpi_spec.
  def tarea(fecha)
    Tarea.create!(club: club, creada_por: admin, titulo: "t-#{SecureRandom.hex(2)}",
                  estado: 'pendiente', fecha_programada: fecha)
  end

  before { sign_in_as(admin) }

  describe 'POST /tareas/:id/completar' do
    it 'rechaza la de mañana y explica qué hacer en su lugar' do
      t = tarea(hoy + 1.day)

      post "/api/tareas/#{t.id}/completar", params: { horas_reales: 1 }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to include('cancelá la programada')
      expect(t.reload.estado).to eq('pendiente')
    end

    it 'deja completar la de hoy' do
      t = tarea(hoy)

      post "/api/tareas/#{t.id}/completar", params: { horas_reales: 1 }

      expect(response).to have_http_status(:ok)
      expect(t.reload.estado).to eq('completada')
    end

    it 'deja completar una atrasada (ponerse al día es el caso normal)' do
      t = tarea(hoy - 3.days)

      post "/api/tareas/#{t.id}/completar", params: { horas_reales: 1 }

      expect(response).to have_http_status(:ok)
      expect(t.reload.estado).to eq('completada')
    end

    it 'deja completar una sin fecha: es "cuando se pueda", no una futura' do
      t = tarea(nil)

      post "/api/tareas/#{t.id}/completar", params: { horas_reales: 1 }

      expect(response).to have_http_status(:ok)
      expect(t.reload.estado).to eq('completada')
    end
  end

  describe 'POST /tareas/completar_masivo' do
    # El caso que importa: UNA sola futura mezclada entre válidas tiene que frenar todo. Si el
    # backend filtrara en vez de rechazar, la tanda pasaría en silencio y esa quedaría sin hacer
    # sin que nadie se entere.
    it 'rechaza la tanda completa si hay una sola futura' do
      ayer   = tarea(hoy - 1.day)
      manana = tarea(hoy + 1.day)

      post '/api/tareas/completar_masivo', params: { ids: [ayer.id, manana.id] }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(ayer.reload.estado).to   eq('pendiente')
      expect(manana.reload.estado).to eq('pendiente')
    end

    it 'completa la tanda cuando ninguna es futura' do
      ayer = tarea(hoy - 1.day)
      hoyt = tarea(hoy)

      post '/api/tareas/completar_masivo', params: { ids: [ayer.id, hoyt.id] }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['completadas']).to eq(2)
      expect(ayer.reload.estado).to eq('completada')
      expect(hoyt.reload.estado).to eq('completada')
    end
  end
end
