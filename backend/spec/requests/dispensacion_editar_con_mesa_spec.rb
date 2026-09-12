require 'rails_helper'

# EDITAR UNA DISPENSA DE UN PRODUCTO QUE ESTÁ SOBRE LA MESA.
#
# El techo de una dispensa es el mismo al crear y al editar: lo libre del depósito MÁS lo que la
# mesa de ese mostrador tiene arriba. La edición lo tenía escrito por su cuenta —contra
# `cantidad_disponible_real`, que resta la mesa entera— así que con el producto sobre la mesa daba
# SIEMPRE cero: cambiarle el medio de pago a la dispensa de ayer era imposible.
#
# Lo reportó el socio de Germán probando el dispensario, que es donde el producto vive sobre la
# mesa: "Stock insuficiente para flor_seca: hay 0.0g disponibles", con 18 g arriba y sin haber
# tocado la cantidad.
RSpec.describe 'PATCH /dispensaciones/:id — con el producto sobre la mesa', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }
  let!(:cc)      { CuentaCorriente.create!(paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 100_000) }
  let!(:stock) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: 100, precio_sugerido_ars: 1_000)
  end

  # Administración baja TODO el frasco a la mesa: no se descuenta, se aparta.
  def cargar_mesa(cantidad)
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin,
                               cambios: [{ stock_id: stock.id, cantidad: cantidad }],
                               motivo: 'Carga del día')
    end
  end

  def crear_dispensa(cantidad: 5, medio: 'transferencia')
    post "/pacientes/#{paciente.id}/dispensaciones",
         params: { dispensacion: { stock_id: stock.id, cantidad: cantidad, medio_pago: medio,
                                   fecha_dispensacion: Time.zone.today.to_s } },
         headers: auth_headers, as: :json
    Dispensacion.last
  end

  def json = JSON.parse(response.body)

  before { sign_in_as(admin) }

  context 'la mesa tiene el frasco entero' do
    it 'deja cambiar el medio de pago sin tocar la cantidad (multi-ítem)' do
      cargar_mesa(100)
      d = crear_dispensa(cantidad: 5)
      expect(stock.reload.cantidad_disponible_real.to_f).to eq(0.0) # todo apartado a la mesa

      patch "/dispensaciones/#{d.id}",
            params: { dispensacion: { medio_pago: 'efectivo', aporte_socio_ars: 5_000,
                                      items: [{ stock_id: stock.id, cantidad: 5 }] } },
            headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok), response.body
      expect(d.reload.medio_pago).to eq('efectivo')
      expect(d.cantidad.to_f).to eq(5.0)
      expect(stock.reload.cantidad.to_f).to eq(95.0) # el stock no se movió
    end

    it 'deja cambiar el medio de pago por la vía legacy (sin items)' do
      cargar_mesa(100)
      d = crear_dispensa(cantidad: 5)

      patch "/dispensaciones/#{d.id}",
            params: { dispensacion: { medio_pago: 'efectivo', aporte_socio_ars: 5_000 } },
            headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(d.reload.medio_pago).to eq('efectivo')
      expect(stock.reload.cantidad.to_f).to eq(95.0)
    end

    it 'deja SUBIR la cantidad hasta lo que hay, contando lo que está sobre la mesa' do
      cargar_mesa(100)
      d = crear_dispensa(cantidad: 5)

      patch "/dispensaciones/#{d.id}",
            params: { dispensacion: { aporte_socio_ars: 95_000,
                                      items: [{ stock_id: stock.id, cantidad: 95 }] } },
            headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(stock.reload.cantidad.to_f).to eq(5.0)
    end
  end

  context 'el techo sigue siendo un techo' do
    it 'rechaza más de lo que hay, y lo dice con el producto y los dos números' do
      cargar_mesa(100)
      d = crear_dispensa(cantidad: 5)

      patch "/dispensaciones/#{d.id}",
            params: { dispensacion: { aporte_socio_ars: 200_000,
                                      items: [{ stock_id: stock.id, cantidad: 200 }] } },
            headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].first).to include('Flor seca', '100.0g', '200.0g')
      expect(stock.reload.cantidad.to_f).to eq(95.0) # rollback: la dispensa vieja quedó intacta
    end

    it 'lo reservado a nombre de un paciente SÍ baja el techo, esté o no sobre la mesa' do
      cargar_mesa(100)
      d = crear_dispensa(cantidad: 5)
      Reserva.create!(club: club, paciente: paciente, user: admin, stock: stock, cantidad: 40,
                      fecha_entrega_estimada: 3.days.from_now.to_date)

      patch "/dispensaciones/#{d.id}",
            params: { dispensacion: { aporte_socio_ars: 95_000,
                                      items: [{ stock_id: stock.id, cantidad: 95 }] } },
            headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].first).to include('60.0g') # 100 − 40 reservados
    end
  end
end
