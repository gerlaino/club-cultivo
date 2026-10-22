require 'rails_helper'
require 'rake'

# AC (22-oct-2026): para cada stock con más sobre la mesa que en el total, decir CÓMO llegó ahí sin
# escribir nada. Si un reconteo cargó como total lo que había SÓLO en el depósito (lo contado ≈
# total − mesa), lo marca: la mesa es real y el que quedó corto es el total.
RSpec.describe 'rake stocks:historia_mesa' do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'stocks:historia_mesa' } }

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'mixta', nombre: 'Centro') }
  let(:stock) do
    ActsAsTenant.with_tenant(club) do
      Stock.create!(club: club, sede: sede, origen: 'compra_externa', proveedor: 'X', forma_producto: 'flor_seca',
                    unidad: 'g', cantidad: 168, cantidad_inicial: 168, estado: 'asignado', disponibilidad: 'ambas')
    end
  end

  def correr(codigos = nil)
    ENV['CODIGOS'] = codigos
    Rake::Task['stocks:historia_mesa'].reenable
    out = StringIO.new
    $stdout = out
    Rake::Task['stocks:historia_mesa'].invoke
    out.string
  ensure
    $stdout = STDOUT
    ENV.delete('CODIGOS')
  end

  # 168 en total, 115 sobre la mesa, y alguien pesa el frasco del depósito (53) y lo carga como
  # total: así quedaba antes de (fu), que ya no bajaba la mesa.
  before do
    ActsAsTenant.with_tenant(club) do
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'carga',
                               cambios: [{ stock_id: stock.id, cantidad: 115 }])
      stock.update!(cantidad: 53)
      stock.stock_movimientos.create!(tipo: 'ajuste', gramos: -115, usuario: admin, notas: '[RECONTEO] pesé el frasco')
    end
  end

  it 'marca el reconteo que contó sólo el depósito y el momento en que la mesa pasó al total' do
    salida = correr
    expect(salida).to include(stock.numero_lote_producto)
    expect(salida).to include('CONTÓ SÓLO EL DEPÓSITO')
    expect(salida).to include('ACÁ LA MESA PASA AL TOTAL')
    expect(salida).to match(/causa: total ajuste\s+1/)
  end

  it 'un reconteo que encontró de verdad menos (no coincide con el depósito) no se lee como «sólo el depósito»' do
    ActsAsTenant.with_tenant(club) do
      otro = Stock.create!(club: club, sede: sede, origen: 'compra_externa', proveedor: 'Y', forma_producto: 'flor_seca',
                           unidad: 'g', cantidad: 200, cantidad_inicial: 200, estado: 'asignado', disponibilidad: 'ambas')
      Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'carga',
                               cambios: [{ stock_id: otro.id, cantidad: 50 }])
      otro.update!(cantidad: 20)
      otro.stock_movimientos.create!(tipo: 'ajuste', gramos: -180, usuario: admin, notas: '[RECONTEO] faltaba')
      salida = correr(otro.numero_lote_producto)
      expect(salida).to include('no coincide con el depósito')
      expect(salida).not_to include('CONTÓ SÓLO EL DEPÓSITO')
    end
  end

  # Desde (fu) el mismo reconteo también baja la mesa: el stock ya no tiene mesa de más, así que
  # se lista aparte para ver si se sacó de la mesa producto que estaba.
  it 'lista la mesa que bajó por un reconteo del stock' do
    ActsAsTenant.with_tenant(club) do
      stock.bajar_mesa_al_total!(usuario: admin, motivo: 'Reconteo del stock: pesé el frasco')
    end
    salida = correr
    expect(salida).to include('MESA BAJADA POR UN RECONTEO DEL STOCK (desde el 20-oct): 1')
    expect(salida).to match(/#{stock.numero_lote_producto}\s+-62\.00/)
  end

  it 'no escribe nada' do
    expect { correr }.not_to(change { [Stock.unscoped.pluck(:cantidad), MostradorItem.unscoped.pluck(:cantidad)] })
  end
end
