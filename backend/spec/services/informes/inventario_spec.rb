require 'rails_helper'

# AC (Germán, 29-sep-2026): un informe de stock «donde vemos los stocks con su información,
# parecido al de dispensaciones pero enfocado en el stock». Opción A: qué hay hoy (con su valor),
# qué pasó con cada stock en el período, qué vence y qué no se mueve. Propio y externo.
RSpec.describe Informes::Inventario do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'mixta', nombre: 'Centro') }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:critical) { create(:genetica, club: club, nombre: 'Critical Kush') }
  let(:lote)     { create(:lote, club: club, sala: sala, genetica: critical, codigo: 'L-26-001') }
  let(:ana)      { create(:paciente, club: club, created_by: admin, dni: '30111222') }

  let(:desde) { Time.zone.today.beginning_of_month.beginning_of_day }
  let(:hasta) { Time.zone.today.end_of_month.end_of_day }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def informe(f = Informes::Filtros.new(club: club)) = described_class.new(club: club, desde: desde, hasta: hasta, filtros: f).call
  def fila(d, stock) = d[:stocks].find { |f| f[:id] == stock.id }

  def propio!(cantidad: 100, **extra)
    Stock.create!(sede: sede, lote: lote, origen: 'lote', genetica: critical, forma_producto: 'flor_seca',
                  unidad: 'g', cantidad: cantidad, precio_sugerido_ars: 1000, costo_unitario_ars: 400, **extra)
  end

  def externo!(cantidad: 50, forma: 'flor_seca', **extra)
    Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'Coop Sur', forma_producto: forma,
                  unidad: forma == 'preroll' ? 'un' : 'g', cantidad: cantidad, precio_sugerido_ars: 800, **extra)
  end

  def dispensar(stock, cantidad, fecha: Time.zone.today)
    Dispensacion.create!(paciente: ana, user: admin, sede: sede, medio_pago: 'efectivo', fecha_dispensacion: fecha,
                         items_attributes: [{ stock: stock, cantidad: cantidad }])
  end

  it 'lista stock propio y externo, cada uno con de dónde viene' do
    p = propio!
    e = externo!
    d = informe
    expect(fila(d, p)).to include(origen: 'propio', de_donde: 'L-26-001', genetica: 'Critical Kush')
    expect(fila(d, e)).to include(origen: 'externo', de_donde: 'Coop Sur')
  end

  it 'lo dispensado en el período sale de las líneas, y queda lo que hay hoy' do
    p = propio!(cantidad: 100)
    dispensar(p, 30)
    f = fila(informe, p.reload)
    expect(f[:dispensado]).to eq(30.0)
    expect(f[:queda]).to eq(70.0)
  end

  it 'lo dispensado antes del período no cuenta como dispensado del período' do
    p = propio!(cantidad: 100)
    p.update_columns(created_at: 3.months.ago)
    dispensar(p, 20, fecha: 2.months.ago.to_date)
    expect(fila(informe, p.reload)[:dispensado]).to eq(0.0)
  end

  # El pesaje de manicura suma a `cantidad_inicial` Y deja un movimiento `produccion`: contar los
  # dos declaraba el doble de lo que entró.
  it 'un stock que nació en el período ingresó su cantidad inicial, sin contar dos veces el pesaje' do
    s = Stock.create!(sede: sede, lote: lote, origen: 'lote', genetica: critical, forma_producto: 'flor_seca',
                      unidad: 'g', cantidad: 0)
    s.stock_movimientos.create!(tipo: 'produccion', gramos: 120, usuario: admin)
    s.increment!(:cantidad, 120); s.increment!(:cantidad_inicial, 120)

    expect(fila(informe, s)[:ingreso]).to eq(120.0)
  end

  it 'un stock de antes del período ingresó lo que le entró por producción en el período' do
    s = propio!(cantidad: 100)
    s.update_columns(created_at: 3.months.ago)
    s.stock_movimientos.create!(tipo: 'produccion', gramos: 40, usuario: admin)
    expect(fila(informe, s)[:ingreso]).to eq(40.0)
  end

  it 'merma y otras salidas van en columnas distintas' do
    s = propio!(cantidad: 100)
    s.stock_movimientos.create!(tipo: 'merma', gramos: -5, usuario: admin)
    s.stock_movimientos.create!(tipo: 'salida', gramos: -10, usuario: admin)
    expect(fila(informe, s)).to include(merma: 5.0, otras_salidas: 10.0)
  end

  it 'por unidad, nunca sumado entre unidades' do
    propio!(cantidad: 100)
    externo!(cantidad: 12, forma: 'preroll')
    hoy = informe[:hoy][:por_unidad]
    expect(hoy.map { |x| [x[:unidad], x[:origen], x[:queda]] }).to contain_exactly(['g', 'propio', 100.0], ['un', 'externo', 12.0])
  end

  it 'el valor de lo que queda, a costo y a precio de venta, y avisa lo que no tiene costo' do
    propio!(cantidad: 10)      # costo 400, precio 1000
    externo!(cantidad: 5)      # sin costo, precio 800
    hoy = informe[:hoy]
    expect(hoy[:valor_costo]).to eq(4000.0)
    expect(hoy[:valor_venta]).to eq(14_000.0)
    expect(hoy[:sin_costo]).to eq(1)
  end

  it 'libre es el mismo número que valida la dispensa' do
    p = propio!(cantidad: 100)
    expect(fila(informe, p)[:libre]).to eq(p.reload.disponible_para_entregar.to_f)
  end

  it 'un agotado de hace tiempo no entra; uno que se agotó en el período, sí' do
    viejo = propio!(cantidad: 0)
    viejo.update_columns(created_at: 1.year.ago)
    nuevo = propio!(cantidad: 10)
    dispensar(nuevo, 10)

    ids = informe[:stocks].map { |f| f[:id] }
    expect(ids).to include(nuevo.id)
    expect(ids).not_to include(viejo.id)
  end

  it 'sin merch ni bebidas' do
    m = Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'X', forma_producto: 'externo',
                      categoria: 'merch', unidad: 'un', cantidad: 5, descripcion: 'Remera')
    expect(informe[:stocks].map { |f| f[:id] }).not_to include(m.id)
  end

  describe 'lo que no se mueve y lo que vence' do
    it 'con saldo y sin salida hace más de un mes: aparece; con salida reciente, no' do
      quieto = propio!(cantidad: 50)
      quieto.update_columns(created_at: 2.months.ago)
      dispensar(quieto, 5, fecha: 40.days.ago.to_date)
      activo = propio!(cantidad: 50)
      activo.update_columns(created_at: 2.months.ago)
      dispensar(activo, 5)

      ids = informe[:sin_movimiento].map { |f| f[:id] }
      expect(ids).to include(quieto.id)
      expect(ids).not_to include(activo.id)
    end

    it 'lo que vence en 30 días, y lo vencido con saldo' do
      pronto  = propio!(fecha_vencimiento_est: Time.zone.today + 10)
      vencido = propio!(fecha_vencimiento_est: Time.zone.today - 3)
      lejos   = propio!(fecha_vencimiento_est: Time.zone.today + 90)

      ids = informe[:vencen].map { |f| f[:id] }
      expect(ids).to eq([vencido.id, pronto.id])
      expect(ids).not_to include(lejos.id)
    end
  end

  describe 'filtros' do
    def f(**x) = Informes::Filtros.new(club: club, **x)

    it 'sólo stock externo' do
      propio!
      e = externo!
      expect(informe(f(origen: 'externo'))[:stocks].map { |x| x[:id] }).to eq([e.id])
    end

    it 'por lote: con UN lote, sus stocks; el externo no tiene lote y no entra' do
      p = propio!
      externo!
      expect(informe(f(lote_ids: [lote.id]))[:stocks].map { |x| x[:id] }).to eq([p.id])
    end

    it 'por genética: toma la del stock o, si no tiene, la de su lote' do
      s = Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 10)
      expect(informe(f(genetica_ids: [critical.id]))[:stocks].map { |x| x[:id] }).to include(s.id)
    end

    it 'con saldo / agotados' do
      con = propio!(cantidad: 10)
      sin = propio!(cantidad: 10)
      dispensar(sin, 10)
      expect(informe(f(saldo: 'con_saldo'))[:stocks].map { |x| x[:id] }).to eq([con.id])
      expect(informe(f(saldo: 'agotados'))[:stocks].map { |x| x[:id] }).to eq([sin.id])
    end
  end
end
