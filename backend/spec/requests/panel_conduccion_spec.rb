require 'rails_helper'

# AC (Germán, 12-oct-2026): el inicio del administrador como panel de conducción. Quien conduce la
# organización tiene que ver en un minuto qué requiere atención (ordenado por impacto), qué está
# dentro de parámetros y los números que conducen; al tocar un asunto, la cuenta a la vista.
# Ningún número del panel puede decir distinto que la pantalla que lo detalla.
RSpec.describe 'Panel de conducción', type: :request do
  let(:club)   { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin)  { create(:user, :admin, club: club, first_name: 'Ada', last_name: 'Admin') }
  let(:lucia)  { create(:user, :dispensador, club: club, first_name: 'Lucía', last_name: 'Mesa') }
  let(:sede)   { create(:sede, club: club, tipo: 'mixta', nombre: 'Centro') }
  let(:paciente) { create(:paciente, club: club, created_by: admin, nombre: 'Ana', apellido: 'Paz') }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, forma_producto: 'flor_seca', unidad: 'g', cantidad: 2_000,
                     estado: 'asignado', disponibilidad: 'ambas', costo_unitario_ars: 100, precio_sugerido_ars: 500)
    end
  end

  def json = JSON.parse(response.body)
  def panel(params = {}) = (get('/api/panel_conduccion', params: params) && json)

  # Un cierre de caja: fondo, lo cobrado en efectivo por una dispensa, lo declarado al cerrar y,
  # si se pide, un faltante de producto al contar.
  def cierre!(fondo: 10_000, cobrado: 0, declarado: 10_000, faltante_g: 0, cuando: 1.day.ago)
    ActsAsTenant.with_tenant(club) do
      mostrador = sede.mostrador!
      Mostradores::Cargar.call(mostrador: mostrador, usuario: admin, motivo: 'carga',
                               cambios: [{ stock_id: stock.id, cantidad: 300 }])
      t = Mostradores::AbrirCaja.call(mostrador: mostrador, usuario: lucia, efectivo_contado_ars: fondo).turno
      caja = t.caja_turno
      if cobrado.positive?
        d = Dispensacion.create!(paciente: paciente, user: lucia, sede: sede, fecha_dispensacion: Time.zone.today,
                                 items_attributes: [{ stock: stock, cantidad: 1 }], aporte_socio_ars: cobrado)
        d.cobros.destroy_all
        Cobro.create!(dispensacion: d, club: club, created_by: lucia, medio: 'efectivo', monto_ars: cobrado, caja_turno: caja)
      end
      mi = mostrador.items.find_by(stock_id: stock.id)
      Mostradores::CerrarCaja.call(turno: t, usuario: lucia, efectivo_contado_ars: declarado,
                                   conteos: [{ stock_id: stock.id, contado: mi.reload.cantidad - faltante_g }],
                                   notas: 'Un pago por transferencia quedó cargado como efectivo.')
      t.reload.update_columns(cerrado_at: cuando)
      t
    end
  end

  describe 'quién lo ve' do
    it 'el administrador' do
      sign_in_as(admin)
      get '/api/panel_conduccion'
      expect(response).to have_http_status(:ok)
    end

    it 'nadie más del equipo: tiene plata y personas' do
      sign_in_as(lucia)
      get '/api/panel_conduccion'
      expect(response).to have_http_status(:forbidden)
    end

    it 'el autocultivo no: tiene su propio inicio' do
      casa = create(:club, plan: 'personal')
      sign_in_as(create(:user, :admin, club: casa))
      get '/api/panel_conduccion'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'requiere atención' do
    before { sign_in_as(admin) }

    it 'un cierre con faltante de caja, con la cuenta en la línea' do
      cierre!(fondo: 10_000, declarado: 7_600)
      a = panel['atencion'].find { |x| x['tipo'] == 'caja' }
      expect(a['titulo']).to eq('Faltante de caja · Centro')
      expect(a['valor']).to eq(-2_400.0)
      expect(a['detalle']).to include('Responsable: Lucía Mesa', 'Esperado $ 10.000', 'Declarado $ 7.600')
    end

    it 'una diferencia de inventario al contar el mostrador, con su costo' do
      cierre!(faltante_g: 6)
      a = panel['atencion'].find { |x| x['tipo'] == 'inventario' }
      expect(a['titulo']).to eq('Diferencia de inventario · Mostrador Centro')
      expect(a['valor']).to eq(6.0)
      expect(a['impacto_ars']).to eq(600.0)
    end

    it 'lo ya revisado deja de pedir atención' do
      t = cierre!(fondo: 10_000, declarado: 7_600)
      t.update!(revisado_por: admin, revisado_at: Time.current)
      expect(panel['atencion'].map { |x| x['tipo'] }).not_to include('caja')
    end

    it 'ordenado por impacto: lo que más cuesta, primero' do
      cierre!(fondo: 10_000, declarado: 9_900, faltante_g: 50) # $ 100 de caja, $ 5.000 de producto
      tipos = panel['atencion'].map { |x| x['tipo'] }
      expect(tipos.index('inventario')).to be < tipos.index('caja')
    end

    it 'una caja que quedó abierta de un día para otro' do
      ActsAsTenant.with_tenant(club) do
        t = Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: lucia, efectivo_contado_ars: 5_000).turno
        t.caja_turno.update_columns(abierta_at: 3.days.ago)
      end
      a = panel['atencion'].find { |x| x['tipo'] == 'caja_abierta' }
      expect(a['titulo']).to eq('Caja abierta sin cerrar · Centro')
      expect(a['severidad']).to eq('alta')
    end

    # El mismo efectivo no puede aparecer dos veces: lo que ya se rindió y espera que lo reciban
    # es una rendición sin recibir, no efectivo «en mano».
    it 'el efectivo de delivery sin rendir, una sola vez' do
      repartidor = create(:user, :delivery, club: club)
      d = ActsAsTenant.with_tenant(club) do
        Dispensacion.create!(paciente: paciente, user: admin, sede: sede, fecha_dispensacion: Time.zone.today,
                             items_attributes: [{ stock: stock, cantidad: 1 }], aporte_socio_ars: 3_000)
      end
      d.cobros.destroy_all
      Cobro.create!(dispensacion: d, club: club, created_by: repartidor, medio: 'efectivo', monto_ars: 3_000,
                    contexto: 'entrega', rendido: false)
      rend = panel['atencion'].select { |x| x['tipo'].start_with?('rendicion') }
      expect(rend.size).to eq(1)
      expect(rend.first['valor']).to eq(3_000.0)
    end
  end

  # Cada número del panel es el de la pantalla que lo detalla (ver `informe_vs_pantalla_spec.rb`).
  describe 'los números son los de cada pantalla' do
    before { sign_in_as(admin) }

    it 'la flor seca disponible, la misma que Stock' do
      del_panel = panel.dig('inventario', 'flor_seca_disponible_g')
      get '/api/stocks/inventario'
      expect(del_panel).to eq(json.dig('totales', 'total_g').to_f.round(1))
    end

    it 'las cuentas por cobrar, las mismas que Contabilidad' do
      cc = paciente.cuenta_corriente!.tap { |c| c.update!(limite_credito: 50_000, saldo_disponible: -12_500) }
      expect(cc.saldo_disponible).to eq(-12_500)
      del_panel = panel.dig('finanzas', 'cuentas_por_cobrar_ars')
      get '/api/movimientos_contables/dashboard'
      expect(del_panel).to eq(json['por_cobrar'])
      expect(del_panel).to eq(12_500.0)
    end
  end

  describe 'el detalle de un cierre' do
    before { sign_in_as(admin) }

    it 'la conciliación cierra: las líneas suman el esperado, y la diferencia es declarado − esperado' do
      t = cierre!(fondo: 10_000, cobrado: 2_400, declarado: 10_000)
      get "/api/panel_conduccion/cierres/#{t.id}"
      c = json['conciliacion']
      expect(c['lineas'].sum { |l| l['monto'] }).to eq(c['esperado'])
      expect(c['esperado']).to eq(12_400.0)
      expect(c['diferencia']).to eq(-2_400.0)
      expect(json['observacion']).to include('transferencia')
    end

    it 'señala una dispensa en efectivo por el mismo importe que el faltante' do
      t = cierre!(fondo: 10_000, cobrado: 2_400, declarado: 10_000)
      get "/api/panel_conduccion/cierres/#{t.id}"
      causa = json['causas'].find { |x| x['tipo'] == 'mismo_importe' }
      expect(causa['texto']).to include('$ 2.400', 'A. P.')
      expect(causa['texto']).not_to include('Ana Paz') # iniciales, no el nombre
    end

    it 'el cierre de otra organización no existe para este panel' do
      otra = create(:club, features: { 'produccion_dispensa' => true })
      ajeno = ActsAsTenant.with_tenant(otra) do
        s = create(:sede, club: otra, tipo: 'mixta')
        Mostradores::AbrirCaja.call(mostrador: s.mostrador!, usuario: create(:user, :dispensador, club: otra),
                                    efectivo_contado_ars: 0).turno
      end
      get "/api/panel_conduccion/cierres/#{ajeno.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  # Aislamiento: lo de otra organización no aparece en ningún bloque.
  it 'no muestra nada de otra organización' do
    otra = create(:club, features: { 'produccion_dispensa' => true })
    ActsAsTenant.with_tenant(otra) do
      s = create(:sede, club: otra, tipo: 'mixta', nombre: 'Ajena')
      t = Mostradores::AbrirCaja.call(mostrador: s.mostrador!, usuario: create(:user, :dispensador, club: otra),
                                      efectivo_contado_ars: 1_000).turno
      t.caja_turno.update_columns(abierta_at: 5.days.ago)
    end
    sign_in_as(admin)
    texto = panel.to_json
    expect(texto).not_to include('Ajena')
  end
end
