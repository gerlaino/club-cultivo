require 'rails_helper'

# AC (Germán, 12-oct-2026): en Stock, en lugar de las tarjetas, un resumen con una fila por
# producto y unidad (nunca se suman gramos con unidades): en depósito, en mostrador,
# comprometido, disponible, «Alcanza para» (días al ritmo de los últimos 28 días; sin salidas no
# hay número) y «Atención» (vencimientos y sedes debajo del umbral). La flor seca disponible y
# los días que alcanza dicen lo mismo que el panel de conducción.
RSpec.describe 'Stock — resumen por producto', type: :request do
  let(:club)  { create(:club, features: { 'produccion_dispensa' => true }, umbral_stock_g: 50) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:centro) { create(:sede, club: club, tipo: 'mixta', nombre: 'Centro') }
  let(:norte)  { create(:sede, club: club, tipo: 'mixta', nombre: 'Norte') }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  def stock!(sede, forma, unidad, cantidad, **extra)
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, forma_producto: forma, unidad: unidad, cantidad: cantidad,
                     estado: 'asignado', precio_sugerido_ars: 10, **extra)
    end
  end

  def json = JSON.parse(response.body)
  def resumen(params = {}) = (get('/api/stocks/inventario', params: params) && json['totales']['por_producto'])
  def fila(r, forma) = r.find { |x| x['forma'] == forma }

  before { sign_in_as(admin) }

  it 'una fila por producto y unidad; gramos y unidades no se mezclan' do
    stock!(centro, 'flor_seca', 'g', 1_000)
    stock!(norte, 'flor_seca', 'g', 200)
    stock!(centro, 'preroll', 'un', 30)
    r = resumen
    expect(r.map { |x| [x['forma'], x['unidad']] }).to eq([%w[flor_seca g], %w[preroll un]])
    expect(fila(r, 'flor_seca')).to include('stocks' => 2, 'disponible' => 1_200.0)
    expect(fila(r, 'preroll')).to include('disponible' => 30.0)
  end

  it 'cierra: disponible = en depósito + en mostrador − comprometido' do
    s = stock!(centro, 'flor_seca', 'g', 1_000)
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: centro.mostrador!, usuario: admin, motivo: 'carga', cambios: [{ stock_id: s.id, cantidad: 100 }])
    end
    f = fila(resumen, 'flor_seca')
    expect(f['en_deposito']).to eq(900.0)
    expect(f['en_mostrador']).to eq(100.0)
    expect(f['en_deposito'] + f['en_mostrador'] - f['comprometido']).to eq(f['disponible'])
  end

  describe 'alcanza para' do
    it 'sin dispensas en 28 días no hay ritmo: no se inventa un número' do
      stock!(centro, 'preroll', 'un', 30)
      expect(fila(resumen, 'preroll')['alcanza_dias']).to be_nil
    end

    it 'con dispensas, días = disponible ÷ promedio diario; la flor dice lo mismo que el panel' do
      flor = stock!(centro, 'flor_seca', 'g', 1_000)
      ActsAsTenant.with_tenant(club) do
        Mostradores::Cargar.call(mostrador: centro.mostrador!, usuario: admin, motivo: 'carga', cambios: [{ stock_id: flor.id, cantidad: 200 }])
        Dispensacion.create!(paciente: paciente, user: admin, sede: centro, medio_pago: 'efectivo',
                             fecha_dispensacion: Time.zone.today, aporte_socio_ars: 10,
                             items_attributes: [{ stock: flor, cantidad: 56 }])
      end
      f = fila(resumen, 'flor_seca')
      expect(f['dispensa_diaria']).to eq(2.0)              # 56 g / 28 días
      expect(f['alcanza_dias']).to eq((944 / 2.0).floor)   # quedan 944 g

      get '/api/panel_conduccion'
      inv = json['inventario']
      expect(inv['flor_seca_disponible_g']).to eq(f['disponible'])
      expect(inv['cobertura_dias']).to eq(f['alcanza_dias'])
    end
  end

  describe 'atención' do
    it 'sólo la sede que está debajo del umbral, con cuánto tiene' do
      stock!(centro, 'flor_seca', 'g', 500)
      stock!(norte, 'flor_seca', 'g', 20)
      at = fila(resumen, 'flor_seca')['atencion']
      expect(at).to eq(['Norte: debajo del umbral (20 g)'])
    end

    it 'lo vencido y lo que vence en 30 días' do
      stock!(centro, 'preroll', 'un', 10, fecha_vencimiento_est: Time.zone.today - 1)
      stock!(centro, 'preroll', 'un', 10, fecha_vencimiento_est: Time.zone.today + 10)
      stock!(centro, 'preroll', 'un', 10, fecha_vencimiento_est: Time.zone.today + 90)
      expect(fila(resumen, 'preroll')['atencion']).to eq(['1 vencido', '1 vence en 30 días'])
    end
  end

  it 'con una sede elegida, sólo esa; los filtros de fecha y producto de la tabla no lo cambian' do
    stock!(centro, 'flor_seca', 'g', 500)
    stock!(norte, 'flor_seca', 'g', 300)
    expect(fila(resumen(sede_id: norte.id), 'flor_seca')['disponible']).to eq(300.0)
    expect(fila(resumen(forma_producto: 'preroll', fecha_desde: Time.zone.today + 5), 'flor_seca')['disponible']).to eq(800.0)
  end

  it 'el stock de otra organización no aparece' do
    otro = create(:club)
    ActsAsTenant.with_tenant(otro) { create(:stock, club: otro, forma_producto: 'flor_seca', unidad: 'g', cantidad: 999, estado: 'asignado') }
    stock!(centro, 'flor_seca', 'g', 10)
    expect(fila(resumen, 'flor_seca')['disponible']).to eq(10.0)
  end
end
