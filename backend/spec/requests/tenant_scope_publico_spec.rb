require 'rails_helper'

# Blindaje de tenant (prep TEN-01c). Verifica que los contextos sin-tenant (público,
# benchmark cross-club) siguen funcionando con el wrapping de ActsAsTenant y que el
# agregado de plataforma ve TODOS los clubes (no solo el del admin logueado).
RSpec.describe 'Blindaje de tenant — contextos públicos y cross-club', type: :request do
  include AuthHelpers

  it 'require_tenant está activo (TEN-01c) — no revertir sin migrar los contextos sin-tenant' do
    expect(ActsAsTenant.configuration.require_tenant).to be(true)
  end

  describe 'GET /c/:token (carnet público, lookup por token global)' do
    it 'resuelve el paciente por su carnet_token sin importar el tenant' do
      club     = create(:club)
      admin    = create(:user, :admin, club: club)
      paciente = create(:paciente, club: club, created_by: admin)

      get "/c/#{paciente.carnet_token}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['numero_socio']).to eq(paciente.id)
    end
  end

  describe 'GET /public/club (modo club, corre con el tenant de current_club)' do
    it 'devuelve los datos del club sin romper por el wrapping de tenant' do
      club = create(:club, name: 'Club Público Test')

      get '/public/club'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['name']).to eq('Club Público Test')
    end
  end

  describe 'GET /api/benchmark (agregado de plataforma, cross-club)' do
    it 'cuenta pacientes de TODOS los clubes opted-in, no solo el del admin logueado' do
      club_a  = create(:club, benchmark_opt_in: true)
      club_b  = create(:club, benchmark_opt_in: true)
      admin_a = create(:user, :admin, club: club_a)
      admin_b = create(:user, :admin, club: club_b)

      create(:paciente, club: club_a, created_by: admin_a)            # 1 en A
      create_list(:paciente, 3, club: club_b, created_by: admin_b)    # 3 en B

      sign_in_as(admin_a) # su tenant queda fijado a club_a en el request real
      get '/api/benchmark', headers: auth_headers

      expect(response).to have_http_status(:ok)
      plataforma = JSON.parse(response.body)['plataforma']
      expect(plataforma['clubes_participantes']).to eq(2)
      # (1 + 3) / 2 = 2.0. Con el bug (tenant del admin intersectando), club_b contaría 0
      # y el promedio caería a 0.5.
      expect(plataforma['avg_pacientes_activos']).to eq(2.0)
    end

    it 'las métricas del propio club siguen scopeadas al club del admin' do
      club_a  = create(:club, benchmark_opt_in: true)
      club_b  = create(:club, benchmark_opt_in: true)
      admin_a = create(:user, :admin, club: club_a)
      admin_b = create(:user, :admin, club: club_b)

      create(:paciente, club: club_a, created_by: admin_a)
      create_list(:paciente, 5, club: club_b, created_by: admin_b)

      sign_in_as(admin_a)
      get '/api/benchmark', headers: auth_headers

      mi_club = JSON.parse(response.body)['mi_club']
      expect(mi_club['pacientes_activos']).to eq(1) # solo los de club_a
    end
  end
end
