require 'rails_helper'

# LO QUE QUEDÓ EN LA CALLE AL CERRAR EL MES CAE EN EL MES SIGUIENTE (decisión de Germán, sep-2026).
#
# El paquete se arma el 30 y se resuelve el 2: la plata entra cuando se cobra o se rinde, no cuando
# se armó el pedido. Antes el asiento se fechaba con `fecha_dispensacion`, así que un paquete del
# mes anterior metía plata de agosto en julio — y si julio ya estaba cerrado, el asiento no se
# podía crear y la entrega, la rendición y la cancelación rebotaban con "período contable cerrado".
# Cerrar un mes con paquetes en la calle no se bloquea: se avisa.
RSpec.describe 'Delivery con el período contable cerrado', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:juan)  { create(:user, :delivery, club: club, first_name: 'Juan') }
  let(:sede)  { create(:sede, club: club, tipo: 'mixta') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }
  let(:paciente) { create(:paciente, club: club) }
  let!(:cc)   { CuentaCorriente.create!(paciente: paciente, club: club, saldo_disponible: 0, limite_credito: 100_000) }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 1_000, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  let(:hoy)          { Time.zone.today }
  let(:fin_mes_ant)  { (hoy - 1.month).end_of_month }
  let(:fecha_pedido) { fin_mes_ant - 2.days }

  # Un paquete del mes anterior, contra entrega, todavía en la calle.
  def paquete!(estado: 'en_viaje', medio: 'efectivo', cobrar_en_entrega: true)
    ActsAsTenant.with_tenant(club) do
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede, cantidad: 10,
                           medio_pago: medio, aporte_socio_ars: 1_000, fecha_dispensacion: fecha_pedido,
                           cobrar_en_entrega: cobrar_en_entrega, con_envio: true, estado_envio: estado,
                           delivery_id: juan.id, direccion_envio: 'Falsa 123', contacto_nombre: 'X')
    end
  end

  def cerrar_mes_anterior!
    club.update!(contabilidad_cerrada_hasta: fin_mes_ant)
  end

  describe 'entregar después del cierre' do
    it 'la transferencia cobrada en la puerta se asienta HOY, no con la fecha del pedido' do
      d = paquete!
      cerrar_mes_anterior!

      sign_in_as(juan)
      patch "/dispensaciones/#{d.id}/entregar", headers: auth_headers, as: :json,
            params: { cobros: [{ medio: 'transferencia', monto: 1_000 }] }

      expect(response).to have_http_status(:ok), response.body
      mov = d.reload.movimientos_contables.sole
      expect(mov.fecha).to eq(hoy)
      expect(mov.medio_pago).to eq('transferencia')
    end
  end

  describe 'rendir después del cierre' do
    it 'el efectivo del repartidor entra al libro el día que se rinde' do
      d = paquete!
      sign_in_as(juan)
      patch "/dispensaciones/#{d.id}/entregar", headers: auth_headers, as: :json,
            params: { cobros: [{ medio: 'efectivo', monto: 1_000 }] }
      expect(response).to have_http_status(:ok), response.body
      expect(d.reload.movimientos_contables).to be_empty # en tránsito: se asienta al rendir

      cerrar_mes_anterior!
      post '/api/rendiciones', headers: auth_headers, params: { receptor_id: admin.id }
      rendicion_id = JSON.parse(response.body)['id']

      sign_in_as(admin)
      post "/api/rendiciones/#{rendicion_id}/recibir", headers: auth_headers, params: { destino: 'club' }

      expect(response).to have_http_status(:ok), response.body
      mov = d.reload.movimientos_contables.sole
      expect(mov.fecha).to eq(hoy)
      expect(mov.monto_ars).to eq(1_000)
    end
  end

  describe 'cancelar un fallido pagado por adelantado en un mes ya cerrado (el #572 de Germán)' do
    it 'cancela igual: el asiento viejo queda y la devolución se asienta HOY, al lado' do
      d = paquete!(estado: 'fallido', cobrar_en_entrega: false)
      ActsAsTenant.with_tenant(club) do
        Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: admin,
                                            medio: 'transferencia', monto: 1_000, contexto: 'creacion')
      end
      viejo = d.movimientos_contables.sole
      expect(viejo.fecha).to eq(fecha_pedido)
      cerrar_mes_anterior!
      expect(stock.reload.cantidad).to eq(990)

      sign_in_as(admin)
      patch "/dispensaciones/#{d.id}/cancelar_entrega", headers: auth_headers, as: :json,
            params: { motivo: 'no lo quiso' }

      expect(response).to have_http_status(:ok), response.body
      expect(d.reload.estado_envio).to eq('cancelada')
      expect(stock.reload.cantidad).to eq(1_000)

      movs = d.movimientos_contables.order(:id)
      expect(movs.map(&:id)).to include(viejo.id)             # el mes cerrado no se toca
      contra = movs.where(tipo: 'egreso').sole
      expect(contra.fecha).to eq(hoy)
      expect(contra.monto_ars).to eq(1_000)
      expect(contra.medio_pago).to eq('transferencia')
      expect(contra.descripcion).to match(/Devolución/)
    end

    it 'con el período abierto se borra como siempre, sin contra-asiento' do
      d = paquete!(estado: 'fallido', cobrar_en_entrega: false)
      ActsAsTenant.with_tenant(club) do
        Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: admin,
                                            medio: 'transferencia', monto: 1_000, contexto: 'creacion')
      end

      sign_in_as(admin)
      patch "/dispensaciones/#{d.id}/cancelar_entrega", headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok), response.body
      expect(d.reload.movimientos_contables).to be_empty
    end
  end

  describe 'recibir la rendición con un fallido del mes cerrado' do
    # El paquete que vuelve se cancela al recibir la rendición (`devolver_paquetes!`). Con el
    # candado viejo, un fallido pagado por adelantado hacía rebotar la rendición ENTERA.
    it 'no rebota' do
      pagado  = paquete!(estado: 'fallido', cobrar_en_entrega: false)
      ActsAsTenant.with_tenant(club) do
        Dispensaciones::RegistrarCobro.call(dispensacion: pagado, club: club, usuario: admin,
                                            medio: 'transferencia', monto: 1_000, contexto: 'creacion')
      end
      cobrado = paquete!
      sign_in_as(juan)
      patch "/dispensaciones/#{cobrado.id}/entregar", headers: auth_headers, as: :json,
            params: { cobros: [{ medio: 'efectivo', monto: 1_000 }] }
      cerrar_mes_anterior!

      post '/api/rendiciones', headers: auth_headers, params: { receptor_id: admin.id }
      rendicion_id = JSON.parse(response.body)['id']
      sign_in_as(admin)
      post "/api/rendiciones/#{rendicion_id}/recibir", headers: auth_headers, params: { destino: 'club' }

      expect(response).to have_http_status(:ok), response.body
      expect(pagado.reload.estado_envio).to eq('cancelada')
      expect(pagado.movimientos_contables.where(tipo: 'egreso').count).to eq(1)
    end
  end

  describe 'el tablero contable avisa cuántos quedan en la calle' do
    it 'cuenta los del período que se va a cerrar, no los de este mes' do
      paquete!(estado: 'pendiente')
      paquete!(estado: 'fallido')
      ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede, cantidad: 1,
                             medio_pago: 'efectivo', aporte_socio_ars: 100, fecha_dispensacion: hoy,
                             cobrar_en_entrega: true, con_envio: true, estado_envio: 'pendiente',
                             delivery_id: juan.id, direccion_envio: 'Falsa 123', contacto_nombre: 'X')
      end

      sign_in_as(admin)
      get '/movimientos_contables/dashboard', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['envios_en_la_calle_al_cierre']).to eq(2)
    end
  end
end
