require 'rails_helper'

# AC (Germán, 7-oct-2026): «no puedo eliminar las tareas». Lo que la pantalla ahora ofrece, el
# backend lo tiene que aceptar con las mismas reglas: admin, supervisor y cultivador; una ya hecha,
# sólo admin; y nunca la de otra organización.
RSpec.describe 'Eliminar una tarea', type: :request do
  let(:club)       { create(:club) }
  let(:admin)      { create(:user, :admin, club: club) }
  let(:cultivador) { create(:user, :cultivador, club: club) }

  def tarea(estado: 'pendiente', en: club)
    ActsAsTenant.with_tenant(en) { create(:tarea, club: en, estado: estado) }
  end

  def eliminar!(t) = delete("/tareas/#{t.id}", headers: auth_headers)

  it 'el cultivador elimina una pendiente' do
    t = tarea
    sign_in_as(cultivador)
    eliminar!(t)
    expect(response).to have_http_status(:no_content)
    expect(Tarea.unscoped.where(id: t.id, deleted_at: nil)).to be_empty
  end

  it 'una ya hecha no la borra el cultivador, y lo dice' do
    t = tarea(estado: 'completada')
    sign_in_as(cultivador)
    eliminar!(t)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('administrador')
  end

  it 'el admin sí borra una ya hecha' do
    t = tarea(estado: 'completada')
    sign_in_as(admin)
    eliminar!(t)
    expect(response).to have_http_status(:no_content)
  end

  it 'no toca la tarea de otra organización' do
    otra = create(:club)
    t = tarea(en: otra)
    sign_in_as(admin)
    eliminar!(t)
    expect(response).to have_http_status(:not_found)
    expect(ActsAsTenant.with_tenant(otra) { Tarea.exists?(t.id) }).to be(true)
  end
end
