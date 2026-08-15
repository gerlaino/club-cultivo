require 'rails_helper'

# F3b — el Stock (dispensario) se puede provisionar a un evento del salón, SIEMPRE como APARTADO:
# bloquea la cantidad (nadie más la puede dispensar ni reservar) pero no descuenta, y no suma COGS.
# Vale para todo el stock trazable por igual — propio, derivados y externo (merch/bebida): su
# única salida del inventario es la dispensación. Es la misma mecánica que una Reserva de paciente,
# con otro destinatario.
RSpec.describe 'Provisión de eventos con Stock', type: :request do
  let(:club)   { create(:club, features: { 'bar' => true }) }
  before { club.update_columns(features: club.features.merge('eventos' => true)) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:sede)   { create(:sede, club: club, tipo: 'social') }
  let(:bar)    { create(:barra, club: club, sede: sede) }
  let(:evento) { bar.eventos_bar.create!(club: club, nombre: 'Aniversario', estado: 'planificado') }

  let(:lote)   { create(:lote, club: club) }
  let!(:flor)  do
    create(:stock, club: club, sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                   cantidad: 100, costo_unitario_ars: 50, descripcion: 'Kush')
  end
  let!(:merch) do
    create(:stock, :externo, club: club, sede: sede, cantidad: 40, unidad: 'un',
                             costo_unitario_ars: 1000, descripcion: 'Remera club')
  end

  before { sign_in_as(admin) }

  def path(extra = '') = "/bares/#{bar.id}/eventos/#{evento.id}/provisiones#{extra}"

  def proveer(stock, cantidad)
    post path, params: { provisionable_type: 'Stock', provisionable_id: stock.id, cantidad_prevista: cantidad },
         headers: auth_headers, as: :json
  end

  describe 'stock regulatorio (flor)' do
    it 'lo marca como apartado y lo ubica en el dispensario' do
      proveer(flor, 30)
      expect(response).to have_http_status(:created)
      fila = JSON.parse(response.body)
      expect(fila['apartado']).to be true
      expect(fila['deposito']).to eq('dispensacion')
      expect(fila['unidad']).to eq('g')
      expect(fila['nombre']).to include('Kush')
    end

    it 'al reservar BLOQUEA los gramos sin descontar el inventario' do
      proveer(flor, 30)
      post path('/reservar'), headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)

      flor.reload
      expect(flor.cantidad).to eq(100)                  # el inventario real no se movió
      expect(flor.apartado_para_eventos).to eq(30)      # pero quedaron comprometidos
      expect(flor.cantidad_disponible_real).to eq(70)
      expect(flor.stock_movimientos.count).to eq(0)     # ninguna salida: la flor sale por dispensación
    end

    it 'lo apartado no lo puede pisar una reserva de paciente' do
      proveer(flor, 90)
      post path('/reservar'), headers: auth_headers, as: :json

      paciente = create(:paciente, club: club)
      reserva  = Reserva.new(club: club, paciente: paciente, stock: flor.reload, user: admin,
                             cantidad: 20, fecha_entrega_estimada: Date.current + 3)
      expect(reserva).not_to be_valid
      expect(reserva.errors[:cantidad].join).to include('supera el stock disponible')
    end

    it 'al cerrar el evento libera el apartado y NO suma COGS' do
      proveer(flor, 30)
      post path('/reservar'), headers: auth_headers, as: :json
      prov = evento.provisiones.first

      post path('/cerrar'), params: { consumos: [{ id: prov.id, cantidad_consumida: 12 }], finalizar: true },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)

      flor.reload
      expect(flor.cantidad).to eq(100)                 # sigue sin tocarse
      expect(flor.apartado_para_eventos).to eq(0)      # liberado
      expect(flor.cantidad_disponible_real).to eq(100)
      # 12 g "consumidos" quedan como registro del evento, pero su costo vive en la dispensación
      expect(evento.reload.costo_mercaderia).to eq(0)
    end

    it 'no deja apartar más de lo disponible' do
      proveer(flor, 500)
      post path('/reservar'), headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      # reserva parcial: aparta los 100 que hay y avisa
      expect(JSON.parse(response.body)['advertencias'].join).to include('100')
      expect(flor.reload.apartado_para_eventos).to eq(100)
    end
  end

  # El externo (merch/bebida) se trata IGUAL que la flor: se aparta, no se descuenta. La
  # confusión de dos puertas de salida (mostrador y dispensación) para el mismo ítem no existe.
  describe 'stock externo (merch)' do
    it 'también se aparta, sin descontar el inventario' do
      proveer(merch, 10)
      fila = JSON.parse(response.body)
      expect(fila['apartado']).to be true
      expect(fila['deposito']).to eq('externo')

      post path('/reservar'), headers: auth_headers, as: :json
      merch.reload
      expect(merch.cantidad).to eq(40)                       # el inventario no se movió
      expect(merch.apartado_para_eventos).to eq(10)          # queda bloqueado
      expect(merch.cantidad_disponible_real).to eq(30)
      expect(merch.stock_movimientos.count).to eq(0)         # ninguna salida sin dispensación
    end

    it 'al cerrar libera el apartado y no suma COGS (su costo va por la dispensación)' do
      proveer(merch, 10)
      post path('/reservar'), headers: auth_headers, as: :json
      prov = evento.provisiones.first

      post path('/cerrar'), params: { consumos: [{ id: prov.id, cantidad_consumida: 4 }], finalizar: true },
           headers: auth_headers, as: :json

      expect(merch.reload.cantidad).to eq(40)
      expect(merch.apartado_para_eventos).to eq(0)
      expect(evento.reload.costo_mercaderia).to eq(0)
    end

    # LA REGLA DE ORO SIGUE: por el MOSTRADOR, lo trazable sale sólo por dispensación (con su
    # paciente) o como consumo interno de un evento (declarado y trazado). El POS no vende Stock.
    #
    # Lo que cambió (ago-2026) es que existe un cierre MANUAL del stock, de admin, que pide qué
    # pasó: `salida` para lo que se fue entero —entregado a otra organización, vendido, regalado,
    # uso interno— y `merma` sólo para lo destruido. Nació porque una organización que sólo
    # produce no tenía ninguna salida legítima: descartaba, y eso declaraba destruido producto
    # que estaba intacto en otro lado.
    it 'el mostrador no puede vender stock trazable' do
      expect(StockMovimiento::TIPOS).to contain_exactly(
        'produccion', 'transferencia', 'dispensacion', 'ajuste', 'merma', 'salida', 'consumo_evento'
      )
      # No hay tipo "venta": una venta del POS mueve productos del bar, nunca Stock.
      expect(StockMovimiento::TIPOS).not_to include('venta')
    end
  end

  describe 'buscador de provisión' do
    it 'encuentra stock del dispensario junto a los productos del bar' do
      create(:bar_producto, club: club, bar: bar, nombre: 'Cerveza', stock: 5, costo_ars: 500)
      get path('/buscar'), params: { q: 'Remera' }, headers: auth_headers
      expect(response).to have_http_status(:ok)

      res = JSON.parse(response.body)['resultados']
      remera = res.find { |r| r['provisionable_type'] == 'Stock' }
      expect(remera['nombre']).to include('Remera')
      expect(remera['en_deposito']).to eq(40.0)
      expect(remera['apartado']).to be true # todo Stock se aparta, nunca se descuenta
    end

    it 'no ofrece stock apartado en cuarentena (disponibilidad ninguna)' do
      merch.update!(disponibilidad: 'ninguna')
      get path('/buscar'), params: { q: 'Remera' }, headers: auth_headers
      expect(JSON.parse(response.body)['resultados']).to be_empty
    end

    it 'no filtra stock de otro club' do
      otro_club = create(:club, features: { 'bar' => true })
      otra_sede = create(:sede, club: otro_club, tipo: 'social')
      create(:stock, :externo, club: otro_club, sede: otra_sede, cantidad: 9, descripcion: 'Remera ajena')

      get path('/buscar'), params: { q: 'Remera' }, headers: auth_headers
      nombres = JSON.parse(response.body)['resultados'].map { |r| r['nombre'] }
      expect(nombres.join).to include('Remera club')
      expect(nombres.join).not_to include('ajena')
    end
  end
end
