require 'rails_helper'

# Historial por usuario (audit log, Fase 1): el admin ve, read-only y paginado, lo que hizo cada
# usuario sobre registros auditados (Lote/Plant/Stock/Dispensación). Endpoint + wiring del concern.
RSpec.describe 'Usuario — historial de auditoría', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:actor) { create(:user, :cultivador, club: club) } # el que "hizo" las acciones

  describe 'configuración de campos no auditables' do
    it 'Lote excluye el contador de cache plants_count' do
      expect(Lote.campos_no_auditables).to include('plants_count', 'updated_at')
    end

    it 'Stock excluye la cantidad (ya vive en stock_movimientos)' do
      expect(Stock.campos_no_auditables).to include('cantidad', 'lote_origen_consumido_g')
    end
  end

  describe 'wiring del concern Auditable' do
    it 'editar un Lote registra el cambio con el usuario y excluye plants_count' do
      lote = ActsAsTenant.with_tenant(club) { create(:lote, club: club) }
      Current.user = actor

      ActsAsTenant.with_tenant(club) do
        expect { lote.update!(codigo: 'RENOMBRADO-1', plants_count: 99) }
          .to change(Auditoria, :count).by(1)
      end

      a = ActsAsTenant.with_tenant(club) { Auditoria.recientes.first }
      expect(a.user_id).to eq(actor.id)
      expect(a.accion).to eq('actualizar')
      expect(a.cambios.keys).to include('codigo')
      expect(a.cambios.keys).not_to include('plants_count') # contador de cache = ruido excluido
    ensure
      Current.user = nil
    end
  end

  describe 'GET /usuarios/:id/auditorias' do
    # 12 ediciones + 1 alta del actor; una edición de OTRO club que no debe filtrarse.
    before do
      ActsAsTenant.with_tenant(club) do
        12.times do |i|
          Auditoria.create!(auditable_type: 'Lote', auditable_id: i + 1, club: club, user: actor,
                            accion: 'actualizar', cambios: { 'tamano_maceta' => [7, 11] })
        end
        Auditoria.create!(auditable_type: 'Stock', auditable_id: 1, club: club, user: actor,
                          accion: 'crear', cambios: { 'descripcion' => 'nuevo' })
      end
      otro_club = create(:club)
      otro_user = create(:user, :cultivador, club: otro_club)
      ActsAsTenant.with_tenant(otro_club) do
        Auditoria.create!(auditable_type: 'Lote', auditable_id: 1, club: otro_club, user: otro_user,
                          accion: 'eliminar', cambios: {})
      end
    end

    it 'devuelve las 10 más recientes con paginación' do
      sign_in_as(admin)
      get "/usuarios/#{actor.id}/auditorias", headers: auth_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['data'].size).to eq(10)
      expect(body['total']).to eq(13) # 12 ediciones + 1 alta
      expect(body['has_more']).to be(true)
      expect(body['page']).to eq(1)
    end

    it 'la página 2 trae el resto' do
      sign_in_as(admin)
      get "/usuarios/#{actor.id}/auditorias", params: { page: 2 }, headers: auth_headers
      body = JSON.parse(response.body)
      expect(body['data'].size).to eq(3)
      expect(body['has_more']).to be(false)
    end

    it 'formatea el diff de una edición (campo/de/a) y no en un alta' do
      sign_in_as(admin)
      get "/usuarios/#{actor.id}/auditorias", headers: auth_headers
      body = JSON.parse(response.body)
      edicion = body['data'].find { |a| a['accion'] == 'actualizar' }
      expect(edicion['tipo']).to eq('Lote')
      expect(edicion['cambios']).to include('campo' => 'tamano_maceta', 'de' => 7, 'a' => 11)
      alta = body['data'].find { |a| a['accion'] == 'crear' }
      expect(alta['cambios']).to eq([]) # crear/eliminar se explican solos
    end

    it 'no filtra auditorías de otro club (aislamiento de tenant)' do
      sign_in_as(admin)
      get "/usuarios/#{actor.id}/auditorias", params: { page: 2 }, headers: auth_headers
      body = JSON.parse(response.body)
      tipos = (JSON.parse(response.body)['data']).map { |a| a['accion'] }
      expect(body['total']).to eq(13) # las 13 del club, ninguna del otro
      expect(tipos).not_to include('eliminar') # la del otro club era 'eliminar'
    end

    it 'un no-admin no puede ver el historial' do
      sign_in_as(actor) # cultivador
      get "/usuarios/#{actor.id}/auditorias", headers: auth_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'filtra por tipo' do
      sign_in_as(admin)
      get "/usuarios/#{actor.id}/auditorias", params: { tipo: 'Stock' }, headers: auth_headers
      body = JSON.parse(response.body)
      expect(body['total']).to eq(1)
      expect(body['data'].first['tipo']).to eq('Stock')
    end

    it 'filtra por rango de fechas (desde)' do
      vieja = ActsAsTenant.with_tenant(club) do
        Auditoria.create!(auditable_type: 'Lote', auditable_id: 99, club: club, user: actor, accion: 'crear', cambios: {})
      end
      vieja.update_column(:created_at, 60.days.ago)

      sign_in_as(admin)
      get "/usuarios/#{actor.id}/auditorias", params: { desde: Date.current.to_s }, headers: auth_headers
      body = JSON.parse(response.body)
      expect(body['total']).to eq(13) # las 13 de hoy; la de hace 60 días queda afuera
    end

    it 'respeta per_page y expone total_pages' do
      sign_in_as(admin)
      get "/usuarios/#{actor.id}/auditorias", params: { per_page: 25 }, headers: auth_headers
      body = JSON.parse(response.body)
      expect(body['per_page']).to eq(25)
      expect(body['data'].size).to eq(13) # todo en una página
      expect(body['total_pages']).to eq(1)
    end
  end
end
