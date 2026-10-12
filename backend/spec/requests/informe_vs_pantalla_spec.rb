require 'rails_helper'

# Germán: "bajé un informe de contabilidad que dice que tenemos -no sé cuánto, pero si voy a
# Contabilidad no es así".
#
# Tenía razón, y la causa era de fondo: el P&L sumaba los INGRESOS del libro de caja y les
# restaba los COSTOS IMPUTADOS A LOTES (CostoLote). Dos libros distintos restados entre sí.
# Los egresos reales del libro —un alquiler, un sueldo— no aparecían en ninguna parte del
# informe, así que el resultado no podía coincidir con lo que muestra la pantalla.
#
# Un informe que no coincide con la pantalla es peor que no tenerlo: hace desconfiar de todo
# lo demás. Esto lo fija.
RSpec.describe 'Los informes dicen lo mismo que las pantallas', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }

  before { sign_in_as(admin) }

  def json = JSON.parse(response.body)

  def movimiento!(tipo, monto, fecha: Time.zone.today)
    cat = ActsAsTenant.with_tenant(club) do
      CategoriaContable.where(club_id: club.id, tipo: tipo).first ||
        CategoriaContable.create!(club: club, nombre: "Cat #{tipo}", tipo: tipo)
    end
    ActsAsTenant.with_tenant(club) do
      MovimientoContable.create!(club: club, tipo: tipo, monto_ars: monto, fecha: fecha,
                                 descripcion: "Mov #{tipo}", categoria_contable: cat,
                                 created_by: admin, pagado: true)
    end
  end

  describe 'el resultado del P&L' do
    before do
      movimiento!('ingreso', 100_000)
      movimiento!('egreso',   40_000)
    end

    it 'sale del mismo libro que ve el admin en Contabilidad' do
      get '/api/analytics/contabilidad'

      mes = json['meses'].find { |m| m['ingresos'].to_f > 0 }
      expect(mes['ingresos'].to_f).to eq(100_000.0)
      expect(mes['costos'].to_f).to   eq(40_000.0)
      expect(mes['margen'].to_f).to   eq(60_000.0)
    end

    # Antes los egresos del libro no entraban al informe: se cargaba un alquiler y el margen
    # seguía diciendo lo mismo.
    it 'un egreso cargado a mano cambia el resultado' do
      get '/api/analytics/contabilidad'
      antes = json['meses'].sum { |m| m['margen'].to_f }

      movimiento!('egreso', 25_000)
      get '/api/analytics/contabilidad', params: { bust: true }
      despues = json['meses'].sum { |m| m['margen'].to_f }

      expect(antes - despues).to eq(25_000.0)
    end

    # El costo de producir no es plata que salió de la caja este mes: va aparte y rotulado,
    # no restándose del resultado.
    it 'el costo de producción se informa aparte, no dentro del margen' do
      get '/api/analytics/contabilidad'

      expect(json['meses'].first).to have_key('costo_produccion')
    end
  end

  describe 'el Excel de movimientos' do
    before do
      movimiento!('ingreso', 100_000)
      movimiento!('egreso',   40_000)
    end

    # El Excel se baja para trabajarlo: si su total no es el mismo que el de la pantalla, no
    # sirve para nada.
    it 'su total es el resultado real: ingresos menos egresos' do
      get '/api/movimientos_contables/export_csv.xlsx'

      expect(response).to have_http_status(:ok)
      xml = Zip::File.open_buffer(response.body) { |z| break z.read('xl/worksheets/sheet1.xml') }
      # Egreso en negativo para que la columna sume el resultado y no valores absolutos.
      expect(xml).to include('-40000')
      expect(xml).to include('60000')
    end
  end

  # AC (Germán, 12-oct-2026, Mitocondria): Stock decía 2.865 g de flor seca disponible y el
  # informe de stock 3.843 g. El informe sumaba en «g» la flor con 978 g de otro producto. «Flor
  # seca disponible» es UN número: el mismo en Stock, en el inicio del admin y en el informe.
  describe 'la flor seca disponible' do
    let(:paciente) { create(:paciente, club: club, created_by: admin) }

    def stock!(forma: 'flor_seca', cantidad:, sede_id: sede.id, estado: 'asignado')
      ActsAsTenant.with_tenant(club) do
        Stock.create!(club: club, sede_id: sede_id, origen: 'compra_externa', proveedor: 'Coop', forma_producto: forma,
                      unidad: 'g', cantidad: cantidad, estado: estado)
      end
    end

    before do
      flor = stock!(cantidad: 2000)
      stock!(cantidad: 865.4)
      stock!(forma: 'otro', cantidad: 978)                     # otro producto en gramos
      stock!(cantidad: 50).update_columns(estado: 'agotado')   # dato viejo: agotado con saldo
      ActsAsTenant.with_tenant(club) do
        Reserva.create!(club: club, paciente: paciente, stock: flor, user: admin, cantidad: 15,
                        estado: 'pendiente', fecha_entrega_estimada: Time.zone.today + 3, sena_ars: 0)
      end
    end

    it 'es el mismo número en Stock, en el inicio y en el informe, y no incluye otros productos' do
      get '/api/stocks/inventario'
      en_stock = json['totales']['total_g'].to_f

      get '/api/analytics/dispensador'
      en_inicio = json['stocks'].find { |s| s['forma'] == 'flor_seca' }['cantidad_g'].to_f

      get '/api/informes/stock'
      en_informe = json['hoy']['flor_seca_disponible'].to_f

      expect(en_stock).to eq(2850.4)   # 2.000 + 865,4 − 15 reservados; sin el «otro» ni el agotado
      expect(en_inicio).to eq(en_stock)
      expect(en_informe).to eq(en_stock)
    end
  end

  describe 'el informe de dispensaciones' do
    let(:paciente) { create(:paciente, club: club, created_by: admin) }
    let(:stock)    { create(:stock, club: club, sede: sede, cantidad: 500) }

    before do
      Dispensacion.create!(paciente: paciente, user: admin, stock: stock, cantidad: 30,
                           fecha_dispensacion: Time.zone.today)
    end

    it 'los gramos del informe son los mismos que los del historial' do
      get '/api/informes/dispensaciones'
      del_informe = json['salio']['por_unidad'].find { |u| u['unidad'] == 'g' }['cantidad'].to_f

      get '/api/dispensaciones'
      lista = json.is_a?(Array) ? json : (json['data'] || json['dispensaciones'])
      del_historial = lista.sum { |d| d['cantidad'].to_f }

      expect(del_informe).to eq(del_historial)
    end
  end
end
