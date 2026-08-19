require 'rails_helper'

# Blindaje de tenant (prep TEN-01c). Verifica que los contextos sin-tenant (público,
# benchmark cross-club) siguen funcionando con el wrapping de ActsAsTenant y que el
# agregado de plataforma ve TODOS los clubes (no solo el del admin logueado).
RSpec.describe 'Blindaje de tenant — contextos públicos y cross-club', type: :request do
  include AuthHelpers

  it 'require_tenant está activo (TEN-01c) — no revertir sin migrar los contextos sin-tenant' do
    expect(ActsAsTenant.configuration.require_tenant).to be(true)
  end

  describe 'GET /api/c/:token (carnet público, lookup por token global)' do
    it 'resuelve el paciente por su carnet_token sin importar el tenant' do
      club     = create(:club)
      admin    = create(:user, :admin, club: club)
      paciente = ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin) }

      get "/api/c/#{paciente.carnet_token}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['numero_socio']).to eq(paciente.id)
    end
  end

  # Lo que la organización le muestra a sus miembros DEJÓ de ser público. Servía siempre
  # `Club.first` —la web multi-club nunca funcionó— y cualquiera leía el catálogo entero sabiendo
  # la URL. Ahora el club sale del usuario logueado.
  describe 'el contenido de la organización ya no es público' do
    it 'sin login no se llega al catálogo, las novedades ni los eventos' do
      create(:club, name: 'Club Público Test')

      %w[/api/portal/club /api/portal/geneticas /api/portal/noticias
         /api/portal/eventos /api/portal/galeria].each do |ruta|
        get ruta
        expect(response).not_to have_http_status(:ok), "#{ruta} contestó sin login"
      end
    end

    it 'la vieja ruta pública del club ya no existe' do
      # No devuelve 404 sino el index.html de la SPA: /public/* dejó de ser API y cae al fallback.
      expect(Rails.application.routes.recognize_path('/public/club'))
        .to include(controller: 'application', action: 'spa_fallback')
    end
  end

  describe 'GET /api/benchmark (agregado de plataforma, cross-club)' do
    it 'cuenta pacientes de TODOS los clubes opted-in, no solo el del admin logueado' do
      club_a  = create(:club, benchmark_opt_in: true)
      club_b  = create(:club, benchmark_opt_in: true)
      admin_a = create(:user, :admin, club: club_a)
      admin_b = create(:user, :admin, club: club_b)

      ActsAsTenant.with_tenant(club_a) { create(:paciente, club: club_a, created_by: admin_a) }            # 1 en A
      ActsAsTenant.with_tenant(club_b) { create_list(:paciente, 3, club: club_b, created_by: admin_b) }    # 3 en B

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

      ActsAsTenant.with_tenant(club_a) { create(:paciente, club: club_a, created_by: admin_a) }
      ActsAsTenant.with_tenant(club_b) { create_list(:paciente, 5, club: club_b, created_by: admin_b) }

      sign_in_as(admin_a)
      get '/api/benchmark', headers: auth_headers

      mi_club = JSON.parse(response.body)['mi_club']
      expect(mi_club['pacientes_activos']).to eq(1) # solo los de club_a
    end
  end
end
