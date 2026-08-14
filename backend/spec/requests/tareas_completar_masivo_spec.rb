require 'rails_helper'

# AC (Germán, probando como manicura): "mismo error al querer marcar una tarea asignada como
# completada" → POST /tareas/completar_masivo devolvía 403.
#
# La causa: `completar_masivo` estaba en el mismo guard que editar y borrar (admin/cultivador/
# supervisor), pero completar de a UNA no lo está. La misma acción, dos caminos, dos permisos: el
# manicura tildaba su tarea asignada, veía el botón "Completar" y se comía un 403.
#
# Completar una tarea es HACER el trabajo, no gestionarlo. Lo que se acota es el alcance: quien no
# gestiona cierra sólo las suyas — es un `update_all`, así que sin filtro un id ajeno en la lista
# cerraría la tarea de otro sin pasar por ninguna validación.
RSpec.describe 'POST /tareas/completar_masivo', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:manicurador) { create(:user, club: club, role: 'manicura') }
  let(:otro)        { create(:user, club: club, role: 'cultivador') }

  def tarea_para(usuario, fecha: Time.zone.today, estado: 'pendiente')
    club.tareas.create!(titulo: 'Limpieza', tipo: 'limpieza', estado: estado,
                        fecha_programada: fecha, asignada_a: usuario, creada_por: admin)
  end

  def completar(ids)
    post '/tareas/completar_masivo', params: { ids: Array(ids) }, headers: auth_headers
  end

  describe 'el manicura' do
    before { sign_in_as(manicurador) }

    it 'puede cerrar la tarea que le asignaron' do
      tarea = tarea_para(manicurador)

      completar(tarea.id)

      expect(response).to have_http_status(:ok), response.body
      expect(tarea.reload.estado).to eq('completada')
    end

    it 'y varias de una' do
      tareas = Array.new(3) { tarea_para(manicurador) }

      completar(tareas.map(&:id))

      expect(JSON.parse(response.body)['completadas']).to eq(3)
    end

    # El filtro no es cosmético: es un update_all.
    it 'no puede cerrar la tarea de otra persona metiéndola en la lista' do
      ajena = tarea_para(otro)

      completar(ajena.id)

      expect(ajena.reload.estado).to eq('pendiente')
    end

    it 'y si TODAS son ajenas, se lo dice en vez de contestar "0 completadas"' do
      ajena = tarea_para(otro)

      completar(ajena.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/otra persona|cerradas/i)
    end

    # La regla de las tareas futuras no cambia: no se adelanta el calendario.
    it 'no puede completar una tarea programada para mañana' do
      futura = tarea_para(manicurador, fecha: Time.zone.tomorrow)

      completar(futura.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(futura.reload.estado).to eq('pendiente')
    end
  end

  describe 'quien gestiona tareas' do
    before { sign_in_as(admin) }

    it 'cierra también las de otros: eso es gestionar' do
      ajena = tarea_para(manicurador)

      completar(ajena.id)

      expect(response).to have_http_status(:ok), response.body
      expect(ajena.reload.estado).to eq('completada')
    end
  end

  # Los roles que no tienen nada que ver con tareas siguen afuera (check_tareas_role!).
  describe 'un rol ajeno a las tareas' do
    it 'sigue sin poder' do
      sign_in_as(create(:user, club: club, role: 'abogado'))

      completar([1])

      expect(response).to have_http_status(:forbidden)
    end
  end
end
