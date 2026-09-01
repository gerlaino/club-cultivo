require 'rails_helper'

# Reponer la mesa con el turno andando, y devolver al depósito lo que sobra.
#
# Ninguna de las dos genera `StockMovimiento`: el gramo no salió de la organización ni cambió de
# sede, sigue siendo la misma fila. Lo único que cambia es quién responde por él.
RSpec.describe 'Cargar y devolver en el mostrador', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 500, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  def abrir!(cantidad: 300)
    sign_in_as(admin)
    post "/api/sedes/#{sede.id}/mostrador/abrir", headers: auth_headers,
         params: { monto_inicial_ars: 1_000, items: [{ stock_id: stock.id, cantidad: cantidad }] }
  end

  def cargar!(cantidad, como: admin)
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/cargar", headers: auth_headers,
         params: { stock_id: stock.id, cantidad: cantidad }
    JSON.parse(response.body)
  end

  def devolver!(cantidad, como: admin)
    item = sede.mostrador.turno_abierto.items.first
    sign_in_as(como)
    post "/api/sedes/#{sede.id}/mostrador/devolver", headers: auth_headers,
         params: { item_id: item.id, cantidad: cantidad }
    JSON.parse(response.body)
  end

  describe 'cargar del depósito' do
    before { abrir! }

    it 'suma a lo que ya está sobre la mesa' do
      body = cargar!(200)
      item = body['items'].first

      expect(response).to have_http_status(:ok)
      expect(item['apertura']).to eq(300.0)
      expect(item['repuesta']).to eq(200.0)
      expect(item['esperado']).to eq(500.0)
      # El apartado sube, pero la mercadería no se movió del inventario.
      expect(stock.reload.cantidad.to_f).to eq(500.0)
      expect(stock.apartado_para_mostrador.to_f).to eq(500.0)
      expect(stock.cantidad_disponible_real.to_f).to eq(0.0)
    end

    it 'no deja subir más de lo que queda libre en el depósito' do
      body = cargar!(300) # quedan 200 libres

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/quedan 200/i)
    end

    # Un producto que no estaba sobre la mesa entra como ítem nuevo del mismo turno.
    it 'un producto que no estaba entra como ítem nuevo' do
      otro = ActsAsTenant.with_tenant(club) do
        create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'preroll', unidad: 'un',
                       cantidad: 40, estado: 'asignado', disponibilidad: 'ambas')
      end

      sign_in_as(admin)
      post "/api/sedes/#{sede.id}/mostrador/cargar", headers: auth_headers,
           params: { stock_id: otro.id, cantidad: 12 }

      expect(JSON.parse(response.body)['items'].size).to eq(2)
    end

    it 'cargar no deja movimiento de stock: el gramo no salió de la organización' do
      expect { cargar!(50) }.not_to change { StockMovimiento.where(stock_id: stock.id).count }
    end

    # Si a las 8 de la noche no hay admin, bloquear al dispensador es mandar pacientes a casa.
    # Se permite, se marca, y el admin lo ve.
    it 'el dispensador puede cargar solo, y queda marcado' do
      body = cargar!(50, como: ana)

      expect(response).to have_http_status(:ok)
      expect(body['items'].first['sin_supervision']).to be(true)
      mov = TurnoMostradorMovimiento.unscoped.order(:id).last
      expect(mov.usuario_id).to eq(ana.id)
      expect(mov.tipo).to eq('carga')
    end

    it 'si carga el admin no queda marcado' do
      body = cargar!(50, como: admin)

      expect(body['items'].first['sin_supervision']).to be(false)
    end
  end

  describe 'devolver al depósito' do
    before { abrir! }

    it 'baja lo que hay sobre la mesa y libera el apartado' do
      body = devolver!(100)

      expect(body['items'].first['esperado']).to eq(200.0)
      expect(stock.reload.apartado_para_mostrador.to_f).to eq(200.0)
      expect(stock.cantidad_disponible_real.to_f).to eq(300.0)
      expect(stock.cantidad.to_f).to eq(500.0)
    end

    it 'no se puede devolver más de lo que hay sobre la mesa' do
      body = devolver!(400)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to match(/hay 300/i)
    end
  end

  describe 'las señales de la pantalla' do
    def ver
      sign_in_as(admin)
      get "/api/sedes/#{sede.id}/mostrador", headers: auth_headers
      JSON.parse(response.body)
    end

    it 'avisa REPONER cuando queda poco arriba pero hay abajo' do
      abrir!(cantidad: 100)
      ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: create(:paciente, club: club), user: admin, stock: stock,
                             sede: sede, cantidad: 85, medio_pago: 'efectivo',
                             aporte_socio_ars: 1_000, fecha_dispensacion: Time.zone.today)
      end

      item = ver['turno']['items'].first
      expect(item['esperado']).to eq(15.0)
      expect(item['en_deposito']).to eq(400.0)
      expect(item['senal']).to eq('reponer')
    end

    # La señal importante: no queda arriba y tampoco abajo. El club se quedó sin ese producto.
    it 'avisa SIN REPUESTO cuando no queda arriba ni abajo' do
      abrir!(cantidad: 500) # todo el frasco sobre la mesa
      ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: create(:paciente, club: club), user: admin, stock: stock,
                             sede: sede, cantidad: 480, medio_pago: 'efectivo',
                             aporte_socio_ars: 1_000, fecha_dispensacion: Time.zone.today)
      end

      item = ver['turno']['items'].first
      expect(item['en_deposito']).to eq(0.0)
      expect(item['senal']).to eq('sin_repuesto')
    end

    it 'sin nada raro, ninguna señal' do
      abrir!(cantidad: 300)

      expect(ver['turno']['items'].first['senal']).to be_nil
    end
  end
end
