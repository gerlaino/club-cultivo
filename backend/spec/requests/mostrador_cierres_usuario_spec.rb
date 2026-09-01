require 'rails_helper'

# Los cabos sueltos que quedaban de cada persona:
#
#   · el que atiende no podía SACAR de la mesa un producto que directamente no estaba
#   · ni mirar sus propios turnos cerrados
#   · el repartidor no veía lo que tiene del club, ni había forma de que lo devolviera
#   · y la bandeja del admin contaba una sola de las tres cosas que prometía
RSpec.describe 'Los cabos sueltos del mostrador', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:flor) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas',
                     costo_unitario_ars: 200, precio_sugerido_ars: 1_000)
    end
  end
  let!(:preroll) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: nil, forma_producto: 'preroll', unidad: 'un',
                     origen: 'compra_externa', proveedor: 'X', cantidad: 50, estado: 'asignado',
                     disponibilidad: 'ambas', costo_unitario_ars: 800)
    end
  end

  def abrir!(como: admin)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/abrir", headers: auth_headers,
         params: { monto_inicial_ars: 0,
                   items: [{ stock_id: flor.id, cantidad: 300 },
                           { stock_id: preroll.id, cantidad: 10 }] }
    JSON.parse(response.body)
  end

  describe 'el producto que directamente NO ESTÁ' do
    # Poner 0 lo dejaría en la mesa toda la jornada, en cero, pidiendo explicación cada vez que
    # alguien mire la pantalla. Se saca.
    it 'se saca de la mesa, no se deja en cero' do
      cuerpo = abrir!
      item = cuerpo['items'].find { |i| i['etiqueta'].match?(/preroll/i) }

      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/mostrador/confirmar", headers: auth_headers,
           params: { correcciones: [{ item_id: item['id'], quitar: true, motivo: 'no estaba' }] }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['items'].size).to eq(1)
      expect(sede.mostrador.turno_abierto.items.en_la_mesa.map(&:stock_id)).to eq([flor.id])
    end

    it 'y queda registrado quién lo sacó y por qué' do
      item = abrir!['items'].find { |i| i['etiqueta'].match?(/preroll/i) }
      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/mostrador/confirmar", headers: auth_headers,
           params: { correcciones: [{ item_id: item['id'], quitar: true, motivo: 'no estaba' }] }

      mov = TurnoMostradorMovimiento.unscoped.correcciones.last
      expect(mov.usuario_id).to eq(ana.id)
      expect(mov.notas).to match(/No estaba sobre la mesa — no estaba/)
    end

    it 'sacarlo sin decir por qué no se acepta' do
      item = abrir!['items'].first
      sign_in_as(ana)
      post "/api/sedes/#{sede.id}/mostrador/confirmar", headers: auth_headers,
           params: { correcciones: [{ item_id: item['id'], quitar: true }] }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(sede.mostrador.turno_abierto.items.count).to eq(2)
    end
  end

  describe 'cuánto vale lo que está sobre la mesa' do
    # En gramos no se compara con nada. En plata se ve de un vistazo que ahí hay medio sueldo.
    it 'lo dice a costo' do
      abrir!
      sign_in_as(admin)
      get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers

      # 300 g × $200 + 10 un × $800
      expect(JSON.parse(response.body)['turno']['valor_mesa_ars']).to eq(68_000.0)
    end
  end

  describe 'sus propios turnos' do
    before do
      abrir!
      turno = sede.mostrador.turno_abierto
      ActsAsTenant.with_tenant(club) do
        Mostradores::ConfirmarApertura.call(turno: turno, usuario: ana)
        Mostradores::CerrarTurno.call(
          turno: turno, usuario: ana, efectivo_contado_ars: 0,
          conteos: turno.items.map { |i| { item_id: i.id, contado: i.esperado } }
        )
      end
    end

    # Cerraba un turno y no tenía dónde mirarlo: si al día siguiente le preguntan por una
    # diferencia, no tenía con qué.
    it 'el que atendió ve los suyos' do
      sign_in_as(ana)
      get "/api/sedes/#{sede.id}/mostrador/turnos", headers: auth_headers

      cuerpo = JSON.parse(response.body)
      expect(cuerpo['turnos'].size).to eq(1)
      expect(cuerpo['gestiona']).to be(false)
      expect(cuerpo['turnos'].first['cerrado_por']).to eq(ana.nombre_completo)
    end

    it 'y no los de otro' do
      otra = create(:user, :dispensador, club: club)
      sign_in_as(otra)
      get "/api/sedes/#{sede.id}/mostrador/turnos", headers: auth_headers

      expect(JSON.parse(response.body)['turnos']).to be_empty
    end

    it 'administración los ve todos' do
      sign_in_as(admin)
      get "/api/sedes/#{sede.id}/mostrador/turnos", headers: auth_headers

      cuerpo = JSON.parse(response.body)
      expect(cuerpo['turnos'].size).to eq(1)
      expect(cuerpo['gestiona']).to be(true)
    end
  end

  # Prometer una bandeja y contar sólo los faltantes deja las otras dos invisibles apenas cierra
  # el turno.
  describe 'la bandeja cuenta las TRES cosas' do
    def cerrar_cuadrado!(turno)
      ActsAsTenant.with_tenant(club) do
        Mostradores::CerrarTurno.call(
          turno: turno, usuario: ana, efectivo_contado_ars: 0,
          conteos: turno.items.map { |i| { item_id: i.id, contado: i.esperado } }
        )
      end
    end

    def sin_revisar
      sign_in_as(admin)
      get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers
      JSON.parse(response.body)['sin_revisar']
    end

    it 'un cierre cuadrado y sin nada raro no entra' do
      abrir!
      t = sede.mostrador.turno_abierto
      ActsAsTenant.with_tenant(club) { Mostradores::ConfirmarApertura.call(turno: t, usuario: ana) }
      cerrar_cuadrado!(t)

      expect(sin_revisar).to eq(0)
    end

    it 'entra si el que atiende corrigió lo que declaró el admin' do
      item = abrir!['items'].first
      t = sede.mostrador.turno_abierto
      ActsAsTenant.with_tenant(club) do
        Mostradores::ConfirmarApertura.call(
          turno: t, usuario: ana,
          correcciones: [{ item_id: item['id'], contado: 297, motivo: 'faltaban 3' }]
        )
      end
      cerrar_cuadrado!(t.reload)

      expect(sin_revisar).to eq(1)
    end

    it 'y entra si alguien bajó del depósito sin un admin al lado' do
      abrir!
      t = sede.mostrador.turno_abierto
      ActsAsTenant.with_tenant(club) do
        Mostradores::ConfirmarApertura.call(turno: t, usuario: ana)
        Mostradores::MoverStock.cargar(turno: t, usuario: ana, stock: flor, cantidad: 10)
      end
      cerrar_cuadrado!(t.reload)

      expect(sin_revisar).to eq(1)
    end
  end
end
