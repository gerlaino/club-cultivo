require 'rails_helper'

# RESERVAR ELIGIENDO DE LA MESA.
#
# La reserva la hace administración y la mercadería se enfrasca recién al entregar: entre una
# cosa y la otra el producto sigue físicamente sobre la mesa del mostrador. De ahí salen las dos
# reglas que este spec fija:
#
#   · los gramos reservados YA ESTÁN adentro de los que el mostrador tiene apartados, así que
#     restarlos otra vez contra el depósito los bloqueaba dos veces;
#   · y no son de quien atiende para entregar: son de un paciente con nombre.
RSpec.describe 'Reservar de lo que está sobre la mesa', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:sede)        { create(:sede, club: club, created_by: admin, tipo: 'social') }
  let(:sala)        { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)        { create(:lote, club: club, sala: sala) }
  let(:paciente)    { create(:paciente, club: club, created_by: admin) }
  let(:dispensador) { create(:user, :dispensador, club: club) }

  let!(:stock) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 1_000, precio_sugerido_ars: 100)
  end

  # Administración baja 110 g a la mesa. NO se descuentan del stock: se apartan.
  def cargar_mesa(cantidad = 110)
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin,
                               cambios: [{ stock_id: stock.id, cantidad: cantidad }],
                               motivo: 'Apertura del día')
    end
  end

  def reservar(cantidad)
    sign_in_as(admin)
    post "/pacientes/#{paciente.id}/reservas",
         params: { reserva: { stock_id: stock.id, cantidad: cantidad,
                              fecha_entrega_estimada: 3.days.from_now.to_date } },
         headers: auth_headers
  end

  describe 'el depósito' do
    it 'no descuenta dos veces: reservar 15 de la mesa deja el depósito como estaba' do
      cargar_mesa(110)
      expect(stock.reload.cantidad_disponible_real).to eq(890.0)

      reservar(15)
      expect(response).to have_http_status(:created)

      # 890 y no 875: los 15 salen de los 110 que ya estaban apartados sobre la mesa.
      expect(stock.reload.cantidad_disponible_real).to eq(890.0)
    end

    it 'lo reservado de algo que NO está sobre la mesa sigue bloqueando el depósito' do
      reservar(15)
      expect(response).to have_http_status(:created)
      expect(stock.reload.cantidad_disponible_real).to eq(985.0)
    end

    it 'si lo reservado supera lo que hay arriba, el excedente sí bloquea depósito' do
      cargar_mesa(10)
      reservar(15)
      expect(response).to have_http_status(:created)
      # max(10, 15) = 15 comprometido, no 25.
      expect(stock.reload.cantidad_disponible_real).to eq(985.0)
    end
  end

  describe 'la mesa' do
    before { cargar_mesa(110) }

    it 'no se toca: el número que se pesa a la noche sigue siendo el mismo' do
      expect { reservar(15) }
        .not_to change { MostradorItem.unscoped.find_by(stock_id: stock.id).cantidad }
      expect(response).to have_http_status(:created)
    end

    it 'lo reservado deja de estar libre para el próximo que llega' do
      reservar(15)
      expect(stock.reload.libre_en_mostrador(sede.id)).to eq(95)
    end

    it 'se puede reservar lo que está arriba aunque el depósito no lo dé por libre' do
      # Toda la fila sobre la mesa: sin la regla nueva, `cantidad_disponible_real` era 0 y no
      # se podía reservar ni un gramo de lo único que hay para reservar.
      cargar_mesa(1_000)
      reservar(40)
      expect(response).to have_http_status(:created)
    end
  end

  describe 'el carrito de quien atiende' do
    before do
      cargar_mesa(110)
      reservar(15)
      dispensador.update!(sedes: [sede]) if dispensador.respond_to?(:sedes=)
    end

    it 'muestra la mesa MENOS lo reservado, y dice cuánto está reservado' do
      sign_in_as(dispensador)
      get '/stocks', params: { para_dispensa: 1 }, headers: auth_headers

      fila = JSON.parse(response.body).find { |s| s['id'] == stock.id }
      expect(fila).to be_present
      # Los dos campos: el carrito muestra y valida contra `cantidad`.
      expect(fila['cantidad']).to eq(95.0)
      expect(fila['cantidad_disponible_real']).to eq(95.0)
      expect(fila['reservado']).to eq(15.0)
      expect(fila['en_la_mesa']).to eq(110.0)
    end
  end

  describe 'al entregarla' do
    it 'baja la mesa y deja el libre del depósito donde estaba' do
      cargar_mesa(110)
      reservar(15)
      reserva = Reserva.last

      sign_in_as(admin)
      patch "/reservas/#{reserva.id}/entregar",
            params: { cobros: [{ medio: 'efectivo', monto: '1500.00' }] }, headers: auth_headers
      expect(response).to have_http_status(:ok)

      stock.reload
      expect(stock.cantidad).to eq(985)                       # salió del inventario
      expect(MostradorItem.unscoped.find_by(stock_id: stock.id).cantidad).to eq(95)
      expect(stock.cantidad_disponible_real).to eq(890.0)     # el depósito, intacto
    end
  end
end
