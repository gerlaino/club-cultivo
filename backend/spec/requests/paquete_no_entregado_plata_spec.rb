require 'rails_helper'

# LO QUE UN PACIENTE PAGÓ POR UN PAQUETE QUE NO SE LE PUDO ENTREGAR (Germán, 23-sep-2026).
#
# Antes el paquete que volvía se anulaba como un error de carga: se borraban el ingreso y los
# cobros. Contra entrega daba igual —no había entrado nada—, pero pagado por adelantado la plata
# desaparecía: del libro, del arqueo, y el paciente no quedaba con nada a favor.
#
# Lo acordado:
#   · lo que ya se pagó QUEDA A FAVOR del paciente, solo, sin que nadie decida nada — porque
#     quien recibe la rendición del repartidor suele ser el dispensador;
#   · administración (admin/supervisor) puede devolvérselo: al cancelar la entrega a mano, o
#     después desde la cuenta corriente.
RSpec.describe 'Paquete no entregado: la plata que ya se pagó', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, features: { 'produccion_dispensa' => true, 'delivery' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:juan)  { create(:user, :delivery, club: club, first_name: 'Juan') }
  let(:dana)  { create(:user, :dispensador, club: club, first_name: 'Dana') }
  let(:sede)  { create(:sede, club: club, tipo: 'mixta') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 1_000, estado: 'asignado', disponibilidad: 'ambas', precio_sugerido_ars: 100)
    end
  end

  def json = JSON.parse(response.body)

  def paciente_nuevo = ActsAsTenant.with_tenant(club) { create(:paciente, club: club) }

  # Un paquete de `total` para `paciente`, con los cobros que se hicieron al armarlo.
  def paquete!(paciente, total:, cobros: [], contra_entrega: false)
    ActsAsTenant.with_tenant(club) do
      d = Dispensacion.create!(paciente: paciente, user: admin, stock: stock, sede: sede,
                               cantidad: 10, medio_pago: 'efectivo', aporte_socio_ars: total,
                               fecha_dispensacion: Time.zone.today, con_envio: true,
                               cobrar_en_entrega: contra_entrega, delivery_id: juan.id,
                               direccion_envio: 'Falsa 123', contacto_nombre: 'X')
      cobros.each do |medio, monto|
        res = Dispensaciones::RegistrarCobro.call(dispensacion: d, club: club, usuario: admin,
                                                  medio: medio, monto: monto, contexto: 'creacion')
        raise res.error unless res.ok?
      end
      d
    end
  end

  def fallar!(d) = d.update!(estado_envio: 'fallido', motivo_fallo: 'no había nadie', fallido_at: Time.current)

  def a_favor(paciente) = paciente.cuenta_corriente!.reload.saldo_disponible.to_d

  def ingresos_de(d) = MovimientoContable.unscoped.where(dispensacion_id: d.id).where(tipo: %w[ingreso recupero_costo]).sum(:monto_ars).to_d

  # Una entrega cobrada en la puerta, para que Juan tenga algo que rendir además de lo que vuelve.
  before do
    entregado = paquete!(paciente_nuevo, total: 5_000, contra_entrega: true)
    ActsAsTenant.with_tenant(club) do
      Dispensaciones::RegistrarCobro.call(dispensacion: entregado, club: club, usuario: juan,
                                          medio: 'efectivo', monto: 5_000, contexto: 'entrega')
      entregado.update!(estado_envio: 'entregado', entregado_at: Time.current)
    end
  end

  describe 'al recibir la rendición (la recibe el dispensador)' do
    let!(:turno) { abrir_mostrador!(sede, usuario: admin, recibe: dana) }

    def rendir_y_recibir!
      sign_in_as(juan)
      post '/api/rendiciones', headers: auth_headers, params: { receptor_id: dana.id }
      id = json['id']
      sign_in_as(dana)
      post "/api/rendiciones/#{id}/recibir", headers: auth_headers
      expect(response).to have_http_status(:ok)
    end

    it 'pagado por adelantado: el ingreso y el cobro quedan, y el paciente lo tiene a favor' do
      ana = paciente_nuevo
      d = paquete!(ana, total: 3_000, cobros: [['transferencia', 3_000]])
      fallar!(d)

      rendir_y_recibir!

      expect(d.reload.estado_envio).to eq('cancelada')
      expect(ingresos_de(d)).to eq(3_000)                                   # no se borró del libro
      expect(Cobro.where(dispensacion_id: d.id).sum(:monto_ars)).to eq(3_000) # ni del arqueo
      expect(a_favor(ana)).to eq(3_000)
      mov = ana.cuenta_corriente.movimientos.find_by(tipo: 'a_favor')
      expect(mov.monto).to eq(3_000)
      expect(mov.dispensacion_id).to eq(d.id)
    end

    it 'contra entrega sin pagar nada: no queda nada a favor y el ingreso no existe' do
      beto = paciente_nuevo
      d = paquete!(beto, total: 2_000, contra_entrega: true)
      fallar!(d)

      rendir_y_recibir!

      expect(d.reload.estado_envio).to eq('cancelada')
      expect(a_favor(beto)).to eq(0)
      expect(ingresos_de(d)).to eq(0)
    end

    it 'pagó una parte y el resto era contra entrega: queda a favor sólo lo que pagó' do
      caro = paciente_nuevo
      d = paquete!(caro, total: 4_000, cobros: [['transferencia', 1_000]], contra_entrega: true)
      fallar!(d)

      rendir_y_recibir!

      expect(a_favor(caro)).to eq(1_000)
    end

    # Lo que pagó con plata a favor vuelve por la reversa de la cuenta corriente; lo que pagó en
    # efectivo queda a favor. Entre los dos, recupera todo lo que puso — y el efectivo sigue en
    # el cajón, así que el arqueo no se mueve.
    it 'pagó con plata a favor y efectivo: recupera todo, y la caja sigue esperando el efectivo' do
      dora = paciente_nuevo
      ActsAsTenant.with_tenant(club) { dora.cuenta_corriente!.update!(saldo_disponible: 500) }
      d = paquete!(dora, total: 2_000, cobros: [['saldo_a_favor', 500], ['efectivo', 1_500]])
      fallar!(d)
      expect(a_favor(dora)).to eq(0)
      esperado = turno.caja_turno.reload.efectivo_esperado_ars.to_d

      rendir_y_recibir!

      expect(a_favor(dora)).to eq(2_000)
      expect(turno.caja_turno.reload.efectivo_esperado_ars.to_d - esperado).to eq(5_000) # sólo lo rendido
    end

    it 'la rendición le muestra a quien recibe cuánto había pagado cada paquete' do
      d = paquete!(paciente_nuevo, total: 3_000, cobros: [['transferencia', 3_000]])
      fallar!(d)

      sign_in_as(juan)
      post '/api/rendiciones', headers: auth_headers, params: { receptor_id: dana.id }

      paquete = json['devoluciones'].find { |p| p['id'] == d.id }
      expect(paquete['pagado_ars']).to eq(3_000.0)
    end
  end

  describe 'administración cancela la entrega a mano' do
    let(:eva) { paciente_nuevo }
    let(:d)   { paquete!(eva, total: 3_000, cobros: [['transferencia', 3_000]]) }

    # El diálogo de Despachos pregunta qué hacer con la plata sólo si hay plata: el listado dice
    # cuánto pagó cada envío que todavía se puede cancelar.
    it 'el listado de despachos dice cuánto había pagado' do
      contra = paquete!(paciente_nuevo, total: 1_000, contra_entrega: true)
      d
      sign_in_as(admin)
      get '/api/dispensaciones', headers: auth_headers, params: { con_envio: 'true' }

      filas = json['dispensaciones'].index_by { |x| x['id'] }
      expect(filas[d.id]['pagado_ars']).to eq(3_000.0)
      expect(filas[contra.id]['pagado_ars']).to eq(0.0)
    end

    it 'por defecto, lo que pagó queda a favor' do
      sign_in_as(admin)
      patch "/api/dispensaciones/#{d.id}/cancelar_entrega", headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json['a_favor_ars']).to eq(3_000.0)
      expect(a_favor(eva)).to eq(3_000)
    end

    it 'o se lo devuelve: la cuenta vuelve a cero y queda el egreso, pendiente si es transferencia' do
      sign_in_as(admin)
      patch "/api/dispensaciones/#{d.id}/cancelar_entrega", headers: auth_headers, as: :json,
            params: { plata: 'devolver', devolucion: { medio: 'transferencia' } }

      expect(response).to have_http_status(:ok)
      expect(json['devuelto_ars']).to eq(3_000.0)
      expect(a_favor(eva)).to eq(0)
      egreso = MovimientoContable.unscoped.find_by(dispensacion_id: d.id, categoria: 'devolucion_paciente')
      expect(egreso.monto_ars).to eq(3_000)
      expect(egreso.pagado).to be(false)
      expect(ingresos_de(d)).to eq(3_000) # el ingreso original queda: la plata entró
    end

    it 'en efectivo sale de la caja elegida, y tiene que alcanzar' do
      turno = abrir_mostrador!(sede, usuario: admin, recibe: dana, fondo: 1_000)
      sign_in_as(admin)
      patch "/api/dispensaciones/#{d.id}/cancelar_entrega", headers: auth_headers, as: :json,
            params: { plata: 'devolver', devolucion: { medio: 'efectivo', caja_turno_id: turno.caja_turno.id } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].first).to match(/En la caja hay/)
      expect(d.reload.estado_envio).not_to eq('cancelada') # no se hizo nada a medias
      expect(a_favor(eva)).to eq(0)
    end
  end

  describe 'devolver plata a favor desde la cuenta corriente' do
    let(:fede) { paciente_nuevo }
    before { ActsAsTenant.with_tenant(club) { fede.cuenta_corriente!.update!(saldo_disponible: 2_000) } }

    def devolver!(como:, monto:, medio: 'transferencia', paciente: fede)
      sign_in_as(como)
      post "/api/pacientes/#{paciente.id}/cuenta_corriente/devolver", headers: auth_headers,
           params: { monto: monto, medio: medio }, as: :json
    end

    it 'el admin devuelve una parte: baja lo que tiene a favor y queda el egreso' do
      devolver!(como: admin, monto: 1_500)

      expect(response).to have_http_status(:created)
      expect(a_favor(fede)).to eq(500)
      expect(fede.cuenta_corriente.movimientos.find_by(tipo: 'devolucion').monto).to eq(-1_500)
      expect(MovimientoContable.unscoped.where(paciente_id: fede.id, categoria: 'devolucion_paciente').sum(:monto_ars)).to eq(1_500)
    end

    it 'el supervisor también' do
      devolver!(como: create(:user, :supervisor, club: club), monto: 2_000)

      expect(response).to have_http_status(:created)
      expect(a_favor(fede)).to eq(0)
    end

    it 'el dispensador no' do
      devolver!(como: dana, monto: 500)

      expect(response).to have_http_status(:forbidden)
      expect(a_favor(fede)).to eq(2_000)
    end

    it 'no se devuelve más de lo que tiene a favor' do
      devolver!(como: admin, monto: 2_500)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to match(/tiene \$2\.000 a favor/)
      expect(a_favor(fede)).to eq(2_000)
    end

    it 'ni a un paciente que debe' do
      ActsAsTenant.with_tenant(club) { fede.cuenta_corriente.update!(saldo_disponible: -300, limite_credito: 1_000) }
      devolver!(como: admin, monto: 100)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'un admin de otra organización no ve al paciente' do
      otro_club = create(:club, features: { 'produccion_dispensa' => true })
      devolver!(como: create(:user, :admin, club: otro_club), monto: 500)

      expect(response).to have_http_status(:not_found)
      expect(a_favor(fede)).to eq(2_000)
    end
  end
end
