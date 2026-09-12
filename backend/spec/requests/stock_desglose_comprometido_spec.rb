require 'rails_helper'

# LO COMPROMETIDO DE UN STOCK VIAJA DESGLOSADO, cada parte con su nombre.
#
# `gramos_reservados` es la SUMA de todo —paquetes en la calle, eventos, reservas y la mesa del
# mostrador— y cuatro pantallas lo etiquetaban "En delivery" o "Reservado": un frasco de 46 g
# subido entero al mostrador se leía «Disponible 0 · En delivery 46» sin que existiera un solo
# reparto. Lo que las pantallas muestran ahora es el desglose, y este spec fija que cada parte
# cuente SÓLO lo suyo.
RSpec.describe 'El stock dice de qué está hecho lo comprometido', type: :request do
  include AuthHelpers

  let(:club)     { create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true }) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:delivery) { create(:user, club: club, role: 'delivery') }
  let(:sede)     { create(:sede, club: club, tipo: 'social', created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: sala) } }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 100, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  def subir_a_la_mesa!(cantidad)
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'carga',
                               cambios: [{ stock_id: stock.id, cantidad: cantidad }])
    end
  end

  def ficha
    sign_in_as(admin)
    get "/api/stocks/#{stock.id}", headers: auth_headers
    JSON.parse(response.body)['data']
  end

  context 'con el frasco entero sobre la mesa y nada más' do
    before { subir_a_la_mesa!(100) }

    it 'la mesa es un lugar, no un reparto: en delivery 0, reservado 0, sobre la mesa 100' do
      f = ficha

      expect(f['en_mostrador_g']).to eq(100.0)
      expect(f['en_delivery_g']).to eq(0.0)
      expect(f['reservado']).to eq(0.0)
      expect(f['apartado_eventos_g']).to eq(0.0)
      # Y se puede entregar entero: la mesa no resta del techo de la dispensa.
      expect(f['disponible_para_entregar']).to eq(100.0)
    end

    it 'el QR del frasco dice lo mismo' do
      sign_in_as(admin)
      get "/api/stocks/qr/#{stock.codigo_qr}", headers: auth_headers
      q = JSON.parse(response.body)

      expect(q['en_mostrador_g']).to eq(100.0)
      expect(q['en_delivery_g']).to eq(0.0)
      expect(q['disponible_para_entregar']).to eq(100.0)
    end
  end

  context 'con un paquete en la calle' do
    before do
      ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                             cantidad: 10, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today,
                             aporte_socio_ars: 1_000, con_envio: true, delivery_id: delivery.id,
                             estado_envio: 'pendiente', direccion_envio: 'Calle 1', contacto_nombre: 'C')
      end
    end

    it 'en delivery cuenta SÓLO el paquete, y el paquete ya salió del frasco' do
      f = ficha

      expect(f['en_delivery_g']).to eq(10.0)
      expect(f['cantidad'].to_f).to eq(90.0)
      expect(f['en_mostrador_g']).to eq(0.0)
    end
  end

  # El canal en vivo dejó de llevar números: eran los del depósito y las listas los pegaban
  # encima de los que el índice había traducido para quien atiende. Ahora es un timbre.
  it 'el broadcast de stock actualizado no lleva cantidades' do
    allow(ActionCable.server).to receive(:broadcast)
    d = ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                           cantidad: 5, medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today,
                           aporte_socio_ars: 500)
    end
    # El callback es `after_create_commit`: se lo llama a mano para no depender de si la
    # transacción del test lo dispara.
    d.send(:broadcast_stock_actualizado)

    expect(ActionCable.server).to have_received(:broadcast)
      .with("stocks_club_#{club.id}", { tipo: 'stock_actualizado', stock_id: stock.id })
  end
end
