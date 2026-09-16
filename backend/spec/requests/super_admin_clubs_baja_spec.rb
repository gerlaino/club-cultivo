require 'rails_helper'

# AC (Germán): suspender y eliminar son DOS cosas distintas y estaban en una sola acción.
# "Al eliminar un club sigue apareciendo pero al entrar al detalle se ve eliminado y se puede
# restaurar, es muy confuso."
#
#   Suspender → dar de baja: sigue en la lista, nadie puede entrar, se reactiva y sigue igual.
#   Eliminar  → sale de la lista y LIBERA el nombre, los emails y los DNI. Soft delete: restaurable.
RSpec.describe 'Super admin — baja y eliminación de clubes', type: :request do
  let(:sa)    { create(:user, :super_admin) }
  let(:club)  { create(:club, name: 'Club Uno', slug: 'club_uno') }
  let!(:admin) { create(:user, :admin, club: club, email: 'admin@club.com') }

  before { sign_in_as(sa) }

  def json = JSON.parse(response.body)

  describe 'suspender' do
    # Con MOTIVO: «Suspendida · Reactivar» era un aviso que no se apagaba. Si no pagó, el
    # pendiente es cobrar; el motivo viaja a la cola del panel y al cartel de la organización.
    it 'guarda el motivo y la fecha, y la cola del panel los muestra' do
      patch "/api/super_admin/clubs/#{club.id}/suspender", params: { motivo: 'no_pago' }, as: :json

      expect(json['suspension_motivo']).to eq('no_pago')
      expect(json['suspendida_at']).to     be_present

      get '/api/super_admin/pulso'
      fila = json['atencion']['suspendidos'].find { |c| c['id'] == club.id }
      expect(fila['motivo']).to eq('no_pago')
    end

    it 'un motivo desconocido cae en «otro»' do
      patch "/api/super_admin/clubs/#{club.id}/suspender", params: { motivo: 'x' }, as: :json

      expect(json['suspension_motivo']).to eq('otro')
    end

    it 'el cartel de la organización recibe el motivo' do
      club.suspender!(motivo: 'no_pago')
      reset!

      post '/api/users/sign_in', params: { user: { email: admin.email, password: 'password123' } }, as: :json

      expect(json['motivo']).to eq('no_pago')
    end

    it 'archivada sale de la cola pero sigue en la lista; reactivar la desarchiva' do
      club.suspender!(motivo: 'lo_pidio')

      patch "/api/super_admin/clubs/#{club.id}/archivar"
      expect(json['archivada']).to be(true)

      get '/api/super_admin/pulso'
      expect(json['atencion']['suspendidos'].map { |c| c['id'] }).not_to include(club.id)

      get '/api/super_admin/clubs'
      expect(json.find { |c| c['id'] == club.id }['archivada']).to be(true)

      patch "/api/super_admin/clubs/#{club.id}/reactivar"
      expect(json['archivada']).to be(false)
      expect(json['suspension_motivo']).to be_nil
    end

    it 'no se archiva una que opera' do
      patch "/api/super_admin/clubs/#{club.id}/archivar"

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'el club sigue en la lista, marcado como suspendido' do
      patch "/api/super_admin/clubs/#{club.id}/suspender"

      expect(response).to have_http_status(:ok)
      get '/api/super_admin/clubs'
      fila = json.find { |c| c['id'] == club.id }
      expect(fila).to be_present
      expect(fila['estado']).to eq('suspendido')
    end

    # Ni siquiera pueden entrar: el guard corre antes que cualquier acción, así que el
    # bloqueo aparece en el login y no después de dejarlos pasar a una app vacía.
    it 'sus usuarios no pueden ni iniciar sesión' do
      club.suspender!
      reset!  # sin esto sigue viajando la cookie del super_admin del `before`

      post '/api/users/sign_in', params: { user: { email: admin.email, password: 'password123' } }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json['club_suspendido']).to be(true)
    end

    it 'reactivar lo devuelve a la normalidad' do
      club.suspender!

      patch "/api/super_admin/clubs/#{club.id}/reactivar"

      expect(club.reload.activo).to be(true)
      sign_in_as(admin)
      get '/api/lotes'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'eliminar' do
    it 'sale de la lista' do
      delete "/api/super_admin/clubs/#{club.id}"

      get '/api/super_admin/clubs'
      expect(json.map { |c| c['id'] }).not_to include(club.id)
    end

    it 'se puede pedir la lista de eliminados aparte' do
      club.soft_delete!

      get '/api/super_admin/clubs', params: { eliminados: true }

      fila = json.find { |c| c['id'] == club.id }
      expect(fila['estado']).to eq('eliminado')
    end

    it 'libera el nombre para un club nuevo' do
      club.soft_delete!

      nuevo = Club.new(name: 'Club Uno', slug: 'club_uno')

      expect(nuevo).to be_valid
    end

    it 'libera el email de sus usuarios' do
      club.soft_delete!

      otro = build(:user, email: 'admin@club.com', club: create(:club))

      expect(otro).to be_valid
    end

    # El DNI es único GLOBAL por requisito REPROCANN: si el club se va, su paciente tiene que
    # poder darse de alta en otro.
    it 'libera el DNI de sus pacientes' do
      ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin, dni: '30111222') }
      club.soft_delete!

      otro_club = create(:club)
      otro_admin = create(:user, :admin, club: otro_club)
      repetido = ActsAsTenant.with_tenant(otro_club) {
        build(:paciente, club: otro_club, created_by: otro_admin, dni: '30111222')
      }

      expect(repetido).to be_valid
    end

    it 'restaurar devuelve el club con su nombre, sus usuarios y sus pacientes' do
      ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin, dni: '30111222') }
      club.soft_delete!

      patch "/api/super_admin/clubs/#{club.id}/restaurar"

      expect(response).to have_http_status(:ok)
      club.reload
      expect(club.deleted_at).to be_nil
      expect(club.slug).to eq('club_uno')
      expect(admin.reload.email).to eq('admin@club.com')
      expect(ActsAsTenant.with_tenant(club) { club.pacientes.count }).to eq(1)
    end
  end
end
