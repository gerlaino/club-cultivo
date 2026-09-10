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

    # El diff se sirve LISTO PARA LEER: el nombre del campo en castellano y los valores ya
    # formateados. Antes salía crudo (`tamano_maceta`, y un jsonb como "[object Object]") porque
    # cada pantalla se arreglaba por su cuenta. Ver AuditoriaSerializer.
    it 'sirve el diff de una edición en castellano, y ninguno en un alta' do
      sign_in_as(admin)
      get "/usuarios/#{actor.id}/auditorias", headers: auth_headers
      body = JSON.parse(response.body)
      edicion = body['data'].find { |a| a['accion'] == 'actualizar' }
      expect(edicion['tipo']).to eq('Lote')
      expect(edicion['accion_label']).to eq('Editó')
      expect(edicion['cambios']).to include('campo' => 'tamaño de maceta', 'de' => '7', 'a' => '11')
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

    # EL HISTORIAL ES LO QUE HIZO LA PERSONA, no lo que la app escribió en su nombre. Una dispensa
    # deja dos o tres asientos detrás: los escribe la app, ella dispensó una vez.
    describe 'las consecuencias no tapan los actos' do
      # Un asiento CON dispensación detrás lo escribió la app; sin ella, lo cargó una persona.
      # Hace falta una dispensación de verdad: el asiento la referencia por clave foránea.
      let(:dispensa) do
        ActsAsTenant.with_tenant(club) do
          sede = create(:sede, club: club, tipo: 'mixta')
          lote = create(:lote, club: club, sala: create(:sala, club: club, sede: sede))
          st   = create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca',
                                unidad: 'g', cantidad: 100, estado: 'asignado',
                                disponibilidad: 'ambas', precio_sugerido_ars: 100)
          Dispensacion.new(paciente: create(:paciente, club: club), user: actor, stock: st,
                           sede: sede, cantidad: 1, medio_pago: 'efectivo', aporte_socio_ars: 100,
                           fecha_dispensacion: Time.zone.today)
                      .tap { |d| d.save!(validate: false) }
        end
      end
      let(:mov_de_dispensa) do
        ActsAsTenant.with_tenant(club) do
          create(:movimiento_contable, club: club, created_by: actor, dispensacion_id: dispensa.id)
        end
      end
      let(:mov_a_mano) do
        ActsAsTenant.with_tenant(club) { create(:movimiento_contable, club: club, created_by: actor) }
      end
      let!(:generado) do
        ActsAsTenant.with_tenant(club) do
          Auditoria.create!(auditable_type: 'MovimientoContable', auditable_id: mov_de_dispensa.id,
                            club: club, user: actor, accion: 'crear', cambios: { 'monto_ars' => '100.0' })
        end
      end
      let!(:a_mano) do
        ActsAsTenant.with_tenant(club) do
          Auditoria.create!(auditable_type: 'MovimientoContable', auditable_id: mov_a_mano.id,
                            club: club, user: actor, accion: 'crear', cambios: { 'monto_ars' => '500.0' })
        end
      end

      it 'un asiento generado por una dispensa no aparece' do
        sign_in_as(admin)
        get "/usuarios/#{actor.id}/auditorias", headers: auth_headers

        ids = JSON.parse(response.body)['data'].map { |a| a['id'] }
        expect(ids).not_to include(generado.id)   # lo escribió la dispensa
        expect(ids).to include(a_mano.id)         # esto sí lo hizo la persona
      end

      it 'pero se puede pedir verlo todo' do
        sign_in_as(admin)
        get "/usuarios/#{actor.id}/auditorias", params: { todo: '1' }, headers: auth_headers

        ids = JSON.parse(response.body)['data'].map { |a| a['id'] }
        expect(ids).to include(generado.id)
      end
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
