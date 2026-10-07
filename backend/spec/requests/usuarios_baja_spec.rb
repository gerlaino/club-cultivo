require 'rails_helper'

# AC (7-oct-2026): siendo super admin tengo que poder eliminar usuarios. La persona sale del
# equipo y no entra más, su historia queda, y se la puede volver a dar de alta con el mismo mail.
#
# Desde el panel no andaba NUNCA: sin organización fijada, borrar las salas asignadas reventaba
# con `NoTenantSet` y la pantalla se tragaba el error. Por eso el caso usa a un cultivador CON
# sala asignada: sin dependencias de organización, el bug no aparece.
RSpec.describe 'Dar de baja a una persona del equipo', type: :request do
  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:cultivador)  { create(:user, :cultivador, club: club) }
  let(:super_admin) { create(:user, :super_admin) }

  before do
    ActsAsTenant.with_tenant(club) do
      sala = create(:sala, club: club)
      SalaCultivador.create!(sala: sala, user: cultivador)
    end
  end

  def baja_por_panel! = delete("/api/super_admin/users/#{cultivador.id}", as: :json)

  describe 'desde el panel de plataforma' do
    before { sign_in_as(super_admin) }

    it 'la da de baja aunque tenga salas asignadas' do
      baja_por_panel!

      expect(response).to have_http_status(:no_content)
      expect(User.with_deleted.find(cultivador.id).deleted_at).to be_present
    end

    it 'sale de la lista de usuarios de la plataforma' do
      baja_por_panel!
      get '/api/super_admin/users', as: :json

      ids = JSON.parse(response.body).then { |b| b.is_a?(Hash) ? b['users'] || b['data'] : b }.map { |u| u['id'] }
      expect(ids).not_to include(cultivador.id)
    end

    it 'no puede volver a entrar' do
      email = cultivador.email
      baja_por_panel!

      reset! # sin la cookie del super admin, que si no es la que contesta
      post '/api/users/sign_in', params: { user: { email: email, password: AuthHelpers::DEFAULT_PASSWORD } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'se la puede volver a dar de alta con el mismo mail' do
      email = cultivador.email
      baja_por_panel!

      expect { create(:user, :cultivador, club: club, email: email) }.not_to raise_error
    end

    it 'su historia queda: la fila sigue y deja anotado quién la dio de baja' do
      baja_por_panel!

      fila = User.with_deleted.find(cultivador.id)
      expect(fila.deleted_by_id).to eq(super_admin.id)
      expect(fila.first_name).to eq(cultivador.first_name)
    end

    it 'a otro super admin no' do
      otro = create(:user, :super_admin)
      delete "/api/super_admin/users/#{otro.id}", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(otro.reload.deleted_at).to be_nil
    end
  end

  describe 'desde Equipo de la organización' do
    before { sign_in_as(admin) }

    it 'el admin la da de baja y libera el mail' do
      email = cultivador.email
      delete "/api/usuarios/#{cultivador.id}", as: :json

      expect(response).to have_http_status(:no_content)
      expect(User.with_deleted.find(cultivador.id).deleted_at).to be_present
      expect { create(:user, :cultivador, club: club, email: email) }.not_to raise_error
    end

    it 'a sí mismo no, y lo dice' do
      delete "/api/usuarios/#{admin.id}", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].first).to match(/vos mismo/)
    end

    it 'no toca a alguien de otra organización' do
      otro_club = create(:club)
      ajeno = create(:user, :cultivador, club: otro_club)
      delete "/api/usuarios/#{ajeno.id}", as: :json

      expect(response).to have_http_status(:not_found)
      expect(ajeno.reload.deleted_at).to be_nil
    end
  end
end
