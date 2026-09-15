require 'rails_helper'

# LA RESERVA TIENE CARRITO (Germán, 15-sep-2026): «al momento de crear una dispensa el modal me
# ofrece agregar más de un ítem; quiero poder hacer lo mismo en la reserva».
#
# Por el endpoint: se crea con `items`, cada línea con su precio y el total estimado como suma;
# se edita línea por línea; y al entregar sale UNA dispensa con tantas líneas como la reserva,
# descontando cada frasco lo suyo. El camino viejo (`stock_id` + `cantidad`) sigue andando.
RSpec.describe 'Reserva con carrito', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  let!(:flor) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 100, precio_sugerido_ars: 1_000)
  end
  let!(:prerolls) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'preroll',
                  unidad: 'un', cantidad: 20, precio_sugerido_ars: 500)
  end

  let(:manana) { 3.days.from_now.to_date.to_s }

  before { sign_in_as(admin) }

  def crear(params)
    post "/api/pacientes/#{paciente.id}/reservas", params: { reserva: params }, as: :json
    JSON.parse(response.body)
  end

  describe 'POST con items' do
    it 'crea una reserva con dos líneas y el total como suma de sus precios' do
      body = crear(items: [{ stock_id: flor.id, cantidad: 10 }, { stock_id: prerolls.id, cantidad: 3 }],
                   fecha_entrega_estimada: manana)
      expect(response).to have_http_status(:created), response.body

      r = Reserva.find(body['id'])
      expect(r.items.count).to eq(2)
      expect(r.items.map { |i| [i.stock_id, i.cantidad.to_f, i.precio_unitario_ars.to_f] })
        .to contain_exactly([flor.id, 10.0, 1_000.0], [prerolls.id, 3.0, 500.0])
      # 10 × 1.000 + 3 × 500
      expect(r.aporte_estimado_ars.to_f).to eq(11_500.0)

      # Y la respuesta trae las líneas, con lo que hace falta para preparar cada una.
      expect(body['items'].size).to eq(2)
      expect(body['items'].map { |i| i['forma_producto'] }).to contain_exactly('flor_seca', 'preroll')
    end

    it 'aplica el descuento del paciente al precio de cada línea' do
      paciente.update!(descuento_porcentaje: 10)
      body = crear(items: [{ stock_id: flor.id, cantidad: 10 }], fecha_entrega_estimada: manana)
      expect(response).to have_http_status(:created), response.body
      expect(body['aporte_estimado_ars']).to eq(9_000.0)
    end

    it 'rechaza la reserva entera si UNA línea supera lo disponible, sin crear nada' do
      expect {
        crear(items: [{ stock_id: flor.id, cantidad: 10 }, { stock_id: prerolls.id, cantidad: 21 }],
              fecha_entrega_estimada: manana)
      }.not_to change(Reserva, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('supera el stock disponible')
    end

    it 'sin líneas, dice qué falta' do
      crear(items: [], fecha_entrega_estimada: manana)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('al menos un producto')
    end

    it 'con stock_id + cantidad a secas sigue creando la reserva de una línea' do
      body = crear(stock_id: flor.id, cantidad: 5, fecha_entrega_estimada: manana)
      expect(response).to have_http_status(:created), response.body
      expect(body['items'].size).to eq(1)
      expect(body['cantidad']).to eq(5.0)
      expect(body['aporte_estimado_ars']).to eq(5_000.0)
    end

    it 'no acepta stock de otra organización' do
      otro = create(:club)
      ajeno = ActsAsTenant.with_tenant(otro) do
        otro_admin = create(:user, :admin, club: otro)
        otra_sede  = create(:sede, club: otro, created_by: otro_admin, tipo: 'mixta')
        Stock.create!(sede: otra_sede, origen: 'compra_externa', proveedor: 'X', forma_producto: 'flor_seca',
                      unidad: 'g', cantidad: 50, precio_sugerido_ars: 1)
      end
      crear(items: [{ stock_id: flor.id, cantidad: 1 }, { stock_id: ajeno.id, cantidad: 1 }],
            fecha_entrega_estimada: manana)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('Stock no encontrado')
    end
  end

  describe 'PATCH por línea' do
    let!(:reserva) do
      crear(items: [{ stock_id: flor.id, cantidad: 10 }, { stock_id: prerolls.id, cantidad: 3 }],
            fecha_entrega_estimada: manana)
      Reserva.last
    end

    it 'edita la cantidad de una línea y recalcula el total' do
      linea = reserva.items.find_by(stock_id: prerolls.id)
      patch "/api/reservas/#{reserva.id}", params: { reserva: { items: [{ id: linea.id, cantidad: 5 }] } }, as: :json
      expect(response).to have_http_status(:ok), response.body

      expect(linea.reload.cantidad).to eq(5)
      expect(reserva.reload.cantidad).to eq(15)
      expect(reserva.aporte_estimado_ars.to_f).to eq(12_500.0)
      expect(prerolls.reload.apartado_para_reservas).to eq(5)
    end

    it 'con varias líneas, `cantidad` a secas no alcanza' do
      patch "/api/reservas/#{reserva.id}", params: { reserva: { cantidad: 5 } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('varios productos')
    end

    it 'no deja agrandar una línea por encima de lo disponible' do
      linea = reserva.items.find_by(stock_id: prerolls.id)
      patch "/api/reservas/#{reserva.id}", params: { reserva: { items: [{ id: linea.id, cantidad: 21 }] } }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(linea.reload.cantidad).to eq(3)
    end
  end

  describe 'PATCH entregar' do
    let!(:reserva) do
      crear(items: [{ stock_id: flor.id, cantidad: 10 }, { stock_id: prerolls.id, cantidad: 3 }],
            fecha_entrega_estimada: manana)
      Reserva.last
    end

    it 'crea UNA dispensa con una línea por línea de la reserva y descuenta cada frasco' do
      # Sin seña, el resto entero se cobra al entregar: si no se dice cómo, cae a cuenta corriente
      # y el paciente no la tiene.
      patch "/api/reservas/#{reserva.id}/entregar",
            params: { cobros: [{ medio: 'transferencia', monto: '11500.00' }] }, as: :json
      expect(response).to have_http_status(:ok), response.body

      disp = reserva.reload.dispensacion
      expect(reserva.estado).to eq('entregada')
      expect(disp.items.count).to eq(2)
      expect(disp.items.map { |i| [i.stock_id, i.cantidad.to_f] })
        .to contain_exactly([flor.id, 10.0], [prerolls.id, 3.0])
      expect(disp.cantidad).to eq(13)

      expect(flor.reload.cantidad).to eq(90)
      expect(prerolls.reload.cantidad).to eq(17)
      # Entregada, ya no aparta nada.
      expect(flor.apartado_para_reservas).to eq(0)
      expect(prerolls.apartado_para_reservas).to eq(0)
    end

    it 'permite ajustar la cantidad de una línea al entregar' do
      linea = reserva.items.find_by(stock_id: flor.id)
      patch "/api/reservas/#{reserva.id}/entregar",
            params: { items: [{ id: linea.id, cantidad: 8 }], aporte_socio_ars: '9500.00',
                      cobros: [{ medio: 'transferencia', monto: '9500.00' }] }, as: :json
      expect(response).to have_http_status(:ok), response.body

      disp = reserva.reload.dispensacion
      expect(disp.items.find_by(stock_id: flor.id).cantidad).to eq(8)
      expect(disp.items.find_by(stock_id: prerolls.id).cantidad).to eq(3)
      expect(flor.reload.cantidad).to eq(92)
    end
  end

  describe 'GET' do
    it 'lista las reservas con sus líneas' do
      crear(items: [{ stock_id: flor.id, cantidad: 10 }, { stock_id: prerolls.id, cantidad: 3 }],
            fecha_entrega_estimada: manana)
      get '/api/reservas', as: :json
      expect(response).to have_http_status(:ok)
      lista = JSON.parse(response.body)['reservas']
      expect(lista.size).to eq(1)
      expect(lista.first['items'].size).to eq(2)
    end
  end
end
