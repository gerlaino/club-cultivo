require 'rails_helper'

# AC (socio de Germán, 1-oct-2026): «tengo que armar el informe de septiembre: durante septiembre
# se ingresaron todos estos gramos de todas estas genéticas». En septiembre funcionaba porque todo
# era nuevo; en octubre le carga más a los stocks que ya traía, y «en octubre me tiene que mostrar
# la cantidad que ingresé en octubre, independientemente de si el lote ya estaba o no».
#
# Lo que entró en un mes = los stocks externos dados de alta ese mes (con lo que traían al crearse)
# + la mercadería que llegó ese mes a stocks que ya existían (movimientos `ingreso`, por SU fecha).
# Una corrección de conteo no es un ingreso.
RSpec.describe 'Informes — lo que entró de stock externo, mes por mes' do
  let(:club)    { create(:club) }
  let(:admin)   { create(:user, :admin, club: club) }
  let(:sede)    { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:gorilla) { create(:genetica, club: club, nombre: 'Gorilla') }
  let(:amnesia) { create(:genetica, club: club, nombre: 'Amnesia') }

  let(:septiembre) { [Time.zone.local(2026, 9, 1), Time.zone.local(2026, 9, 30).end_of_day] }
  let(:octubre)    { [Time.zone.local(2026, 10, 1), Time.zone.local(2026, 10, 31).end_of_day] }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def externo!(genetica, cantidad, alta:)
    s = Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'Coop Sur', genetica: genetica,
                      forma_producto: 'flor_seca', unidad: 'g', cantidad: cantidad, estado: 'asignado')
    s.update_columns(created_at: alta, updated_at: alta)
    s
  end

  # Lo mismo que deja «Entró mercadería» (ver `stock_ingreso_mercaderia_spec`).
  def ingreso!(stock, gramos, fecha)
    stock.update!(cantidad: stock.cantidad + gramos)
    stock.stock_movimientos.create!(tipo: 'ingreso', gramos: gramos, fecha: fecha, usuario: admin, notas: '[INGRESO]')
  end

  def reconteo!(stock, gramos, fecha)
    stock.update!(cantidad: stock.cantidad + gramos)
    stock.stock_movimientos.create!(tipo: 'ajuste', gramos: gramos, fecha: fecha, usuario: admin, notas: '[RECONTEO] conté de más')
  end

  describe Informes::Produccion do
    def externo_en((desde, hasta)) = described_class.new(club: club, desde: desde, hasta: hasta).call[:externo]
    def por_genetica(ext) = ext[:por_genetica].to_h { |g| [g[:genetica], g[:cantidad]] }

    it 'un stock de septiembre que recibe más en octubre: cada mes muestra lo suyo' do
      s = externo!(gorilla, 100, alta: Time.zone.local(2026, 9, 10, 12))
      ingreso!(s, 40, Date.new(2026, 10, 5))

      expect(por_genetica(externo_en(septiembre))).to eq('Gorilla' => 100.0)
      expect(por_genetica(externo_en(octubre))).to eq('Gorilla' => 40.0)
      expect(externo_en(octubre)[:stocks].map { |f| f[:tipo] }).to eq(['ingreso'])
    end

    it 'lo que entró el 28-sep y se cargó en octubre cae en septiembre (cuenta la fecha en que entró)' do
      s = externo!(gorilla, 100, alta: Time.zone.local(2026, 9, 10, 12))
      ingreso!(s, 25, Date.new(2026, 9, 28))

      expect(por_genetica(externo_en(septiembre))).to eq('Gorilla' => 125.0)
      expect(externo_en(octubre)[:stocks]).to be_empty
    end

    it 'dos genéticas y sólo UNA recibe en octubre: octubre muestra sólo esa' do
      g = externo!(gorilla, 100, alta: Time.zone.local(2026, 9, 10, 12))
      externo!(amnesia, 80, alta: Time.zone.local(2026, 9, 12, 12))
      ingreso!(g, 40, Date.new(2026, 10, 5))

      expect(por_genetica(externo_en(octubre))).to eq('Gorilla' => 40.0)
      expect(por_genetica(externo_en(septiembre))).to eq('Gorilla' => 100.0, 'Amnesia' => 80.0)
    end

    it 'un alta y un ingreso de la misma genética en el mismo mes se suman en el resumen' do
      s = externo!(gorilla, 100, alta: Time.zone.local(2026, 10, 2, 12))
      ingreso!(s, 40, Date.new(2026, 10, 20))

      ext = externo_en(octubre)
      expect(por_genetica(ext)).to eq('Gorilla' => 140.0)
      expect(ext[:por_genetica].first).to include(altas: 1, ingresos: 1)
      expect(ext[:por_unidad]).to eq([{ unidad: 'g', cantidad: 140.0 }])
    end

    it 'una corrección de conteo no es un ingreso' do
      s = externo!(gorilla, 100, alta: Time.zone.local(2026, 9, 10, 12))
      reconteo!(s, 12, Date.new(2026, 10, 5))

      expect(externo_en(octubre)[:stocks]).to be_empty
    end
  end

  describe Informes::Inventario do
    def informe_en((desde, hasta)) = described_class.new(club: club, desde: desde, hasta: hasta).call
    def ingresos(d) = d[:ingresos].to_h { |x| [x[:genetica], x[:ingreso]] }

    it 'la columna «Ingresó» de un stock de septiembre cuenta lo que le entró en octubre, no su alta' do
      s = externo!(gorilla, 100, alta: Time.zone.local(2026, 9, 10, 12))
      ingreso!(s, 40, Date.new(2026, 10, 5))

      oct = informe_en(octubre)
      expect(oct[:stocks].find { |f| f[:id] == s.id }[:ingreso]).to eq(40.0)
      expect(ingresos(oct)).to eq('Gorilla' => 40.0)
      expect(ingresos(informe_en(septiembre))).to eq('Gorilla' => 100.0)
    end

    it 'un stock dado de alta en el mes con un ingreso en el mismo mes: alta + ingreso' do
      s = externo!(gorilla, 100, alta: Time.zone.local(2026, 10, 2, 12))
      ingreso!(s, 40, Date.new(2026, 10, 20))

      expect(informe_en(octubre)[:stocks].find { |f| f[:id] == s.id }[:ingreso]).to eq(140.0)
    end

    it 'dos genéticas y sólo UNA recibe en octubre: sólo esa en «lo que entró»' do
      g = externo!(gorilla, 100, alta: Time.zone.local(2026, 9, 10, 12))
      externo!(amnesia, 80, alta: Time.zone.local(2026, 9, 12, 12))
      ingreso!(g, 40, Date.new(2026, 10, 5))

      expect(ingresos(informe_en(octubre))).to eq('Gorilla' => 40.0)
    end

    it 'una corrección de conteo queda en «Ajustes», no en «Ingresó»' do
      s = externo!(gorilla, 100, alta: Time.zone.local(2026, 9, 10, 12))
      reconteo!(s, 12, Date.new(2026, 10, 5))

      fila = informe_en(octubre)[:stocks].find { |f| f[:id] == s.id }
      expect(fila).to include(ingreso: 0.0, ajustes: 12.0)
    end
  end

  describe 'rake stocks:balance_descuadrado' do
    it 'un externo con más que su inicial por mercadería que entró no está descuadrado' do
      Rails.application.load_tasks if Rake::Task.tasks.empty?
      s = externo!(gorilla, 100, alta: Time.zone.local(2026, 9, 10, 12))
      ingreso!(s, 40, Date.new(2026, 10, 5))

      salida = capture_stdout { Rake::Task['stocks:balance_descuadrado'].execute }
      expect(salida).to include('El balance cierra en todos')
    end
  end

  describe 'rake stocks:ingresos_desde_reconteo' do
    before { Rails.application.load_tasks if Rake::Task.tasks.empty? }

    def correr(env)
      env.each { |k, v| ENV[k] = v }
      capture_stdout { Rake::Task['stocks:ingresos_desde_reconteo'].execute }
    ensure
      env.each_key { |k| ENV.delete(k) }
    end

    it 'en seco sólo lista; con CONFIRMAR pasa a ingreso, salvo lo EXCLUIDO' do
      s = externo!(gorilla, 100, alta: Time.zone.local(2026, 9, 10, 12))
      cargado    = reconteo!(s, 40, Date.new(2026, 10, 5))
      correccion = reconteo!(s, 3, Date.new(2026, 10, 6))

      expect(correr({})).to include("mov ##{cargado.id}", "mov ##{correccion.id}")
      expect(cargado.reload.tipo).to eq('ajuste')

      correr('EXCLUIR' => correccion.id.to_s, 'CONFIRMAR' => '1')
      expect(cargado.reload).to have_attributes(tipo: 'ingreso')
      expect(cargado.notas).to start_with('[INGRESO] (cargado como reconteo)')
      expect(correccion.reload.tipo).to eq('ajuste')
      expect(s.reload.cantidad.to_f).to eq(143.0) # no toca cantidades
    end

    it 'no toca los reconteos de stock de cosecha ni las bajas' do
      sala = create(:sala, club: club, sede: sede, created_by: admin)
      propio = Stock.create!(sede: sede, lote: create(:lote, club: club, sala: sala), origen: 'lote',
                             forma_producto: 'flor_seca', unidad: 'g', cantidad: 100)
      baja = propio.stock_movimientos.create!(tipo: 'ajuste', gramos: -5, usuario: admin, notas: '[RECONTEO] faltaba')

      correr('CONFIRMAR' => '1')
      expect(baja.reload.tipo).to eq('ajuste')
    end
  end

  def capture_stdout
    viejo = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = viejo
  end
end
