require 'rails_helper'

RSpec.describe 'POST /tareas/:id/completar (tarea de trasplante)', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)  { create(:lote, club: club, sala: sala, tamanio_maceta: 1) }
  let!(:p1)   { create(:plant, lote: lote) }
  let!(:p2)   { create(:plant, lote: lote) }

  let(:tarea) do
    club.tareas.create!(
      titulo: 'Trasplantar a 3L', tipo: 'transplante', estado: 'pendiente',
      prioridad: 'normal', lote: lote, creada_por: admin, asignada_a: admin
    )
  end

  it 'al completar con maceta destino registra el trasplante en el lote' do
    sign_in_as(admin)
    expect {
      post "/tareas/#{tarea.id}/completar",
           params: { maceta_origen_l: 1, maceta_destino_l: 3 },
           headers: auth_headers
    }.to change(PlantActivity.where(activity_type: 'transplant'), :count).by(2)

    expect(response).to have_http_status(:ok)
    expect(tarea.reload.estado).to eq('completada')
    expect(lote.reload.tamanio_maceta.to_f).to eq(3.0)
    act = p1.activities.where(activity_type: 'transplant').last
    expect(act.metadata['maceta_destino_l']).to eq(3.0)
  end

  it 'sin maceta destino completa la tarea sin registrar trasplante' do
    sign_in_as(admin)
    expect {
      post "/tareas/#{tarea.id}/completar", params: {}, headers: auth_headers
    }.not_to change(PlantActivity.where(activity_type: 'transplant'), :count)

    expect(response).to have_http_status(:ok)
    expect(tarea.reload.estado).to eq('completada')
  end
end
