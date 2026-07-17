require 'rails_helper'

RSpec.describe 'POST /api/tareas/completar_masivo', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def crear_tarea(estado: 'pendiente', club_de: club, creada_por: admin)
    Tarea.create!(club: club_de, creada_por: creada_por, titulo: "T-#{SecureRandom.hex(3)}", estado: estado)
  end

  context 'como admin' do
    before { sign_in_as(admin) }

    it 'marca como completadas las tareas pendientes/en_progreso seleccionadas' do
      t1 = crear_tarea(estado: 'pendiente')
      t2 = crear_tarea(estado: 'en_progreso')

      post '/api/tareas/completar_masivo', params: { ids: [t1.id, t2.id] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['completadas']).to eq(2)
      expect(t1.reload.estado).to eq('completada')
      expect(t2.reload.estado).to eq('completada')
      expect(t1.fecha_completada).to be_present
    end

    it 'no toca tareas ya completadas ni canceladas' do
      hecha     = crear_tarea(estado: 'completada')
      cancelada = crear_tarea(estado: 'cancelada')

      post '/api/tareas/completar_masivo', params: { ids: [hecha.id, cancelada.id] }, as: :json

      expect(JSON.parse(response.body)['completadas']).to eq(0)
      expect(cancelada.reload.estado).to eq('cancelada')
    end

    it 'no completa tareas de otro club (aislamiento de tenant)' do
      otro_club  = create(:club)
      otro_admin = create(:user, :admin, club: otro_club)
      ajena      = ActsAsTenant.with_tenant(otro_club) { crear_tarea(club_de: otro_club, creada_por: otro_admin) }
      propia     = crear_tarea

      post '/api/tareas/completar_masivo', params: { ids: [propia.id, ajena.id] }, as: :json

      expect(JSON.parse(response.body)['completadas']).to eq(1)
      expect(propia.reload.estado).to eq('completada')
      expect(ajena.reload.estado).to eq('pendiente')
    end

    it 'devuelve 422 si no se mandan ids' do
      post '/api/tareas/completar_masivo', params: { ids: [] }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'como dispensador (sin permiso de gestión)' do
    it 'responde 403' do
      disp = create(:user, :dispensador, club: club)
      tarea = crear_tarea
      sign_in_as(disp)

      post '/api/tareas/completar_masivo', params: { ids: [tarea.id] }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(tarea.reload.estado).to eq('pendiente')
    end
  end
end
