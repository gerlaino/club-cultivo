require 'rails_helper'

# AC (9-oct-2026, Germán; reemplaza «una futura no se puede dar por hecha»): una tarea de más
# adelante SÍ se puede marcar como hecha, pero con un aviso antes, y queda hecha con la fecha de
# HOY, no con la futura. La regla vive en el backend: todas las pantallas que completan tareas
# reciben el mismo aviso (409 `tarea_futura`) y repiten con `adelantar`.
RSpec.describe 'Completar tareas programadas a futuro', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:hoy)   { Time.zone.today }

  # No hay factory de Tarea; mismo patrón que tareas_pendientes_kpi_spec.

  # Desde el 7-oct-2026 una tarea NUEVA necesita fecha; las viejas sin fecha siguen existiendo en la
  # base y se prueban así: se crea con fecha y se le borra, como quedaron.
  def tarea(fecha)
    t = Tarea.create!(club: club, creada_por: admin, titulo: "t-#{SecureRandom.hex(2)}",
                      estado: 'pendiente', fecha_programada: fecha || Time.zone.today)
    t.update_column(:fecha_programada, nil) if fecha.nil?
    t
  end

  before { sign_in_as(admin) }

  describe 'POST /tareas/:id/completar' do
    it 'la de más adelante, sin confirmar: avisa con su fecha y no la toca' do
      t = tarea(hoy + 14.days)

      post "/api/tareas/#{t.id}/completar", params: { horas_reales: 1 }

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body['codigo']).to eq('tarea_futura')
      expect(body['error']).to include(I18n.l(hoy + 14.days, format: '%-d/%-m')).and include('queda hecha hoy')
      expect(t.reload.estado).to eq('pendiente')
    end

    it 'confirmada: queda hecha HOY, con la fecha programada intacta y la nota de que se adelantó' do
      t = tarea(hoy + 14.days)

      post "/api/tareas/#{t.id}/completar", params: { horas_reales: 1, adelantar: true, notas_completado: 'todo ok' }

      expect(response).to have_http_status(:ok)
      t.reload
      expect(t.estado).to eq('completada')
      expect(t.fecha_completada.in_time_zone.to_date).to eq(hoy)
      expect(t.fecha_programada).to eq(hoy + 14.days)
      expect(t.notas_completado).to start_with('Hecha antes de tiempo').and include('todo ok')
    end

    it 'en el calendario figura el día en que se hizo, no el programado' do
      t = tarea(hoy + 14.days)
      post "/api/tareas/#{t.id}/completar", params: { adelantar: true }

      ids_de = ->(desde) {
        get '/api/tareas/semana', params: { desde: desde.to_s }
        JSON.parse(response.body)['dias'].flat_map { |d| d['tareas'].map { |x| [d['fecha'], x['id']] } }
      }
      lunes = hoy.beginning_of_week(:monday)
      expect(ids_de.(lunes)).to include([hoy.to_s, t.id])
      expect(ids_de.((hoy + 14.days).beginning_of_week(:monday)).map(&:last)).not_to include(t.id)
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
    # El caso que importa: UNA sola futura mezclada entre válidas frena la tanda y avisa. Si el
    # backend la completara en silencio, quedaría hecha sin que nadie lo decidiera.
    it 'con una sola futura en la tanda avisa y no completa ninguna' do
      ayer   = tarea(hoy - 1.day)
      manana = tarea(hoy + 1.day)

      post '/api/tareas/completar_masivo', params: { ids: [ayer.id, manana.id] }

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)['codigo']).to eq('tarea_futura')
      expect(ayer.reload.estado).to   eq('pendiente')
      expect(manana.reload.estado).to eq('pendiente')
    end

    it 'confirmada, completa la tanda; la futura queda hecha hoy y con su nota' do
      ayer   = tarea(hoy - 1.day)
      manana = tarea(hoy + 1.day)

      post '/api/tareas/completar_masivo', params: { ids: [ayer.id, manana.id], adelantar: true }

      expect(response).to have_http_status(:ok)
      expect(manana.reload).to have_attributes(estado: 'completada', fecha_programada: hoy + 1.day)
      expect(manana.notas_completado).to start_with('Hecha antes de tiempo')
      expect(ayer.reload.notas_completado).to be_nil
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
