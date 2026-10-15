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

  # AC (Germán, 7-oct-2026): «33 − 43 + 27 no da 193,8». Cada fila cierra:
  # Había + Ingresó − Dispensado − Merma − Otras salidas ± Ajustes = Quedaba.
  describe 'cada fila cierra' do
    def cierra?(f) = (f[:habia] + f[:ingreso] - f[:dispensado] - f[:merma] - f[:otras_salidas] + f[:ajustes] - f[:quedaba]).abs < 0.01

    def ajuste!(stock, gramos, fecha: Time.zone.today, notas: 'Recuento')
      StockMovimiento.create!(stock: stock, tipo: 'ajuste', gramos: gramos, usuario: admin, notas: notas, fecha: fecha)
      stock.update_columns(cantidad: stock.cantidad + gramos)
    end

    it 'un frasco de antes del período dice cuánto había al empezar' do
      e = externo!(cantidad: 200)
      e.update_columns(created_at: 3.months.ago, cantidad_inicial: 200)
      dispensar(e, 43)
      ajuste!(e.reload, 27)
      f = fila(informe, e.reload)
      expect(f).to include(habia: 200.0, dispensado: 43.0, ajustes: 27.0, quedaba: 184.0)
      expect(cierra?(f)).to be(true)
      expect(f[:descuadre]).to be_nil
    end

    it 'uno que nació en el período había 0' do
      p = propio!(cantidad: 100)
      dispensar(p, 30)
      f = fila(informe, p.reload)
      expect(f).to include(habia: 0.0, ingreso: 100.0, quedaba: 70.0)
      expect(cierra?(f)).to be(true)
    end

    it 'con un período que ya terminó, «Quedaba» es el saldo de entonces, no el de hoy' do
      p = propio!(cantidad: 100)
      p.update_columns(created_at: 3.months.ago, cantidad_inicial: 100)
      dispensar(p, 10, fecha: 40.days.ago.to_date)
      dispensar(p, 25)                                    # después del período
      ajuste!(p.reload, -5, fecha: Time.zone.today)       # también después
      pasado = described_class.new(club: club, desde: 2.months.ago.beginning_of_month, hasta: 1.month.ago.end_of_month).call
      f = pasado[:stocks].find { |x| x[:id] == p.id }
      expect(f[:quedaba]).to eq(90.0)
      expect(f[:queda]).to eq(60.0)
      expect(cierra?(f)).to be(true)
    end

    # AC (Germán y Javi, 15-oct-2026, Mitocondria: 145,7 g que «no cierran»): la historia se cargó
    # el 1-sep — los stocks con alta ese día y sus dispensas con su fecha real, anterior. El informe
    # decía «ingresó 46,5, dispensado 0, quedaba 0». El stock entra el día que empezó a salir.
    describe 'historia cargada después: dispensas con fecha anterior al alta del stock' do
      let(:mes_pasado) { 1.month.ago.to_date }
      let!(:frasco) do
        externo!(cantidad: 46.5).tap do |e|
          dispensar(e, 30, fecha: mes_pasado.beginning_of_month + 5)
          dispensar(e, 16.5, fecha: mes_pasado.beginning_of_month + 9)
        end
      end

      def del_mes_pasado = described_class.new(club: club, desde: mes_pasado.beginning_of_month, hasta: mes_pasado.end_of_month).call

      it 'el período de las dispensas lo muestra entrando y saliendo, y cierra' do
        f = fila(del_mes_pasado, frasco.reload)
        expect(f).to include(habia: 0.0, ingreso: 46.5, dispensado: 46.5, quedaba: 0.0)
        expect(f[:descuadre]).to be_nil
        expect(cierra?(f)).to be(true)
      end

      it 'el período del alta no lo cuenta como ingreso sin salida' do
        f = fila(informe, frasco.reload)
        expect(f).to be_nil
      end

      it 'un stock con alta y dispensas en el mismo período sigue igual' do
        p = propio!(cantidad: 100)
        dispensar(p, 30)
        expect(fila(informe, p.reload)).to include(habia: 0.0, ingreso: 100.0, quedaba: 70.0)
      end
    end

    it 'los ajustes se pueden ver uno por uno: cuándo, cuánto, quién y por qué' do
      e = externo!(cantidad: 50)
      ajuste!(e, 12, notas: 'Apareció un frasco en la heladera')
      det = fila(informe, e.reload)[:ajustes_detalle]
      expect(det.size).to eq(1)
      expect(det.first).to include(gramos: 12.0, notas: 'Apareció un frasco en la heladera')
      expect(det.first[:quien]).to be_present
    end
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

  it 'por producto y unidad, nunca sumado entre unidades' do
    propio!(cantidad: 100)
    externo!(cantidad: 12, forma: 'preroll')
    hoy = informe[:hoy][:por_producto]
    expect(hoy.map { |x| [x[:producto], x[:unidad], x[:origen], x[:queda]] })
      .to contain_exactly(['flor_seca', 'g', 'propio', 100.0], ['preroll', 'un', 'externo', 12.0])
  end

  # AC (Germán, 12-oct-2026, Mitocondria): «si veo que tengo 3 kg de algo y en realidad tengo 2,
  # está pésimo». 2.865 g de flor y 978 g de «otro», los dos en gramos: el informe decía 3.843 g.
  it 'la flor no se suma con otro producto en gramos' do
    propio!(cantidad: 2865.4)
    externo!(cantidad: 978, forma: 'otro')
    hoy = informe[:hoy]
    expect(hoy[:flor_seca_disponible]).to eq(2865.4)
    expect(hoy[:por_producto].map { |x| [x[:producto], x[:queda]] }).to contain_exactly(['flor_seca', 2865.4], ['otro', 978.0])
    expect(informe[:periodo].map { |x| x[:producto] }).to contain_exactly('flor_seca', 'otro')
  end

  it 'un agotado que quedó con saldo no cuenta en lo que hay hoy (como en la pantalla de Stock)' do
    propio!(cantidad: 100)
    viejo = propio!(cantidad: 40)
    viejo.update_columns(estado: 'agotado')
    expect(informe[:hoy][:flor_seca_disponible]).to eq(100.0)
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
