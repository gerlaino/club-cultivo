require 'rails_helper'

# AC (Germán, 29-sep-2026): al elegir un informe se puede armar a gusto —con todos los lotes o con
# algunos, con algunos pacientes, sólo el stock externo…—, y el stock externo (`compra_externa`)
# tiene que aparecer: una organización que sólo carga stock y dispensa no lo veía en ningún informe.
RSpec.describe 'Informes con filtros' do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'mixta', nombre: 'Centro') }
  let(:otra_sede) { create(:sede, club: club, created_by: admin, tipo: 'mixta', nombre: 'Norte') }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin, kind: 'mixta') }
  let(:critical) { create(:genetica, club: club, nombre: 'Critical Kush') }
  let(:northern) { create(:genetica, club: club, nombre: 'Northern Lights') }

  let(:desde) { Time.zone.today.beginning_of_month.beginning_of_day }
  let(:hasta) { Time.zone.today.end_of_month.end_of_day }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def filtros(**f) = Informes::Filtros.new(club: club, **f)

  describe Informes::Filtros do
    it 'sin filtros no está activo y no describe nada' do
      expect(filtros.activo?).to be(false)
      expect(filtros.descripcion).to be_nil
    end

    it 'un id de otra organización no se ignora: el filtro queda vacío' do
      otro  = create(:club)
      ajeno = ActsAsTenant.with_tenant(otro) { create(:lote, club: otro) }
      f = filtros(lote_ids: [ajeno.id.to_s])
      expect(f.lote_ids).to eq([])
      expect(f.activo?).to be(true)
    end

    it 'describe lo que se filtró' do
      l = create(:lote, club: club, sala: sala, codigo: 'L-26-009')
      expect(filtros(lote_ids: [l.id], origen: 'externo').descripcion)
        .to eq('Lotes: L-26-009 · sólo stock externo')
    end
  end

  describe Informes::Produccion do
    def informe(f = filtros) = described_class.new(club: club, desde: desde, hasta: hasta, filtros: f).call

    def cosechado!(genetica:, gramos:, codigo:)
      l = create(:lote, club: club, sala: sala, estado: 'curado', genetica: genetica, codigo: codigo,
                        plants_count_cosechadas: 10, rendimiento_real_g: gramos)
      l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin,
                             registrado_en: Time.zone.now)
      l
    end

    def compra!(forma: 'flor_seca', cantidad: 100, en_sede: sede, genetica: critical, **extra)
      Stock.create!(sede: en_sede, origen: 'compra_externa', proveedor: 'Cooperativa Sur', genetica: genetica,
                    forma_producto: forma, unidad: forma == 'preroll' ? 'un' : 'g', cantidad: cantidad, **extra)
    end

    it 'con UN lote elegido, sólo ese lote' do
      a = cosechado!(genetica: critical, gramos: 500, codigo: 'L-A')
      cosechado!(genetica: northern, gramos: 300, codigo: 'L-B')

      per = informe(filtros(lote_ids: [a.id]))[:periodo]
      expect(per[:lotes].map { |l| l[:codigo] }).to eq(['L-A'])
      expect(per[:gramos]).to eq(500.0)
    end

    # Semántica OR: de los lotes elegidos, alcanza con que UNO se haya cosechado para que entre.
    it 'con varios lotes elegidos y sólo uno cosechado en el período, entra ese' do
      a = cosechado!(genetica: critical, gramos: 500, codigo: 'L-A')
      en_pie = create(:lote, club: club, sala: sala, estado: 'vegetativo', genetica: northern)
      cosechado!(genetica: northern, gramos: 300, codigo: 'L-C')

      per = informe(filtros(lote_ids: [a.id, en_pie.id]))[:periodo]
      expect(per[:lotes].map { |l| l[:codigo] }).to eq(['L-A'])
    end

    it 'por genética: sólo los lotes de esa genética' do
      cosechado!(genetica: critical, gramos: 500, codigo: 'L-A')
      cosechado!(genetica: northern, gramos: 300, codigo: 'L-B')

      expect(informe(filtros(genetica_ids: [northern.id]))[:periodo][:gramos]).to eq(300.0)
    end

    it 'el stock externo en el período aparece, aparte de lo cosechado y sin merch' do
      cosechado!(genetica: critical, gramos: 500, codigo: 'L-A')
      compra!(cantidad: 250)
      compra!(forma: 'preroll', cantidad: 40)
      Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'X', forma_producto: 'externo',
                    categoria: 'merch', unidad: 'un', cantidad: 5, descripcion: 'Remera')

      d = informe
      expect(d[:periodo][:gramos]).to eq(500.0)   # el stock externo no se suma a lo cosechado
      expect(d[:externo][:stocks].map { |s| s[:producto] }).to contain_exactly('flor_seca', 'preroll')
      expect(d[:externo][:por_unidad]).to contain_exactly({ unidad: 'g', cantidad: 250.0 }, { unidad: 'un', cantidad: 40.0 })
    end

    it 'el stock externo cuenta lo que INGRESÓ, aunque ya se haya dispensado parte' do
      s = compra!(cantidad: 100)
      s.update_columns(cantidad: 30)
      expect(informe[:externo][:stocks].first).to include(cantidad: 100.0, disponible: 30.0)
    end

    it 'el stock externo antes del período no entra' do
      compra!(cantidad: 100).update_columns(created_at: 2.months.ago)
      expect(informe[:externo][:stocks]).to be_empty
    end

    it '«sólo stock externo» deja afuera los lotes; «sólo lo propio», las compras' do
      cosechado!(genetica: critical, gramos: 500, codigo: 'L-A')
      compra!(cantidad: 100)

      solo_compra = informe(filtros(origen: 'externo'))
      expect(solo_compra[:periodo][:total_lotes]).to eq(0)
      expect(solo_compra[:externo][:stocks].size).to eq(1)

      solo_propio = informe(filtros(origen: 'propio'))
      expect(solo_propio[:periodo][:total_lotes]).to eq(1)
      expect(solo_propio[:externo][:stocks]).to be_empty
    end

    it 'por sede: el stock externo en otra sede no entra' do
      compra!(cantidad: 100)
      compra!(cantidad: 70, en_sede: otra_sede)

      expect(informe(filtros(sede_ids: [otra_sede.id]))[:externo][:stocks].map { |s| s[:cantidad] }).to eq([70.0])
    end

    it 'con filtro de lotes, el stock externo no entra (no tiene lote)' do
      a = cosechado!(genetica: critical, gramos: 500, codigo: 'L-A')
      compra!(cantidad: 100)
      expect(informe(filtros(lote_ids: [a.id]))[:externo][:stocks]).to be_empty
    end
  end

  describe Informes::Dispensaciones do
    let(:lote)    { create(:lote, club: club, sala: sala, genetica: critical) }
    let(:lote2)   { create(:lote, club: club, sala: sala, genetica: northern) }
    let(:ana)     { create(:paciente, club: club, created_by: admin, dni: '30111222') }
    let(:beto)    { create(:paciente, club: club, created_by: admin, dni: '30111333') }
    let!(:flor)   { Stock.create!(sede: sede, lote: lote,  origen: 'lote', genetica: critical, forma_producto: 'flor_seca', unidad: 'g', cantidad: 1000, precio_sugerido_ars: 100) }
    let!(:flor2)  { Stock.create!(sede: sede, lote: lote2, origen: 'lote', genetica: northern, forma_producto: 'flor_seca', unidad: 'g', cantidad: 1000, precio_sugerido_ars: 100) }
    let!(:comprado) { Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'Coop', genetica: northern, forma_producto: 'preroll', unidad: 'un', cantidad: 100, precio_sugerido_ars: 500) }

    def informe(f = filtros) = described_class.new(club: club, desde: desde, hasta: hasta, filtros: f).call
    def g(d) = d[:salio][:por_unidad].to_h { |x| [x[:unidad], x[:cantidad]] }

    def dispensar(paciente, items)
      Dispensacion.create!(paciente: paciente, user: admin, sede: sede, medio_pago: 'efectivo',
                           fecha_dispensacion: Time.zone.today,
                           items_attributes: items.map { |st, c| { stock: st, cantidad: c } })
    end

    it 'lo dispensado de el stock externo ya aparecía, y sigue' do
      dispensar(ana, { comprado => 6 })
      expect(g(informe)).to eq('un' => 6.0)
    end

    it 'con UN paciente elegido, sólo lo suyo' do
      dispensar(ana, { flor => 10 })
      dispensar(beto, { flor => 30 })

      d = informe(filtros(paciente_ids: [ana.id]))
      expect(d[:pacientes].map { |p| p[:paciente] }).to eq([ana.nombre_completo])
      expect(g(d)).to eq('g' => 10.0)
    end

    # Semántica OR: de los pacientes elegidos, el que no retiró nada simplemente no aparece.
    it 'con varios pacientes elegidos y sólo uno que retiró, aparece ese' do
      dispensar(beto, { flor => 30 })
      otro = create(:paciente, club: club, created_by: admin, dni: '30111444')
      dispensar(otro, { flor => 5 })

      d = informe(filtros(paciente_ids: [ana.id, beto.id]))
      expect(d[:pacientes].map { |p| p[:paciente] }).to eq([beto.nombre_completo])
    end

    it '«sólo stock externo» deja sólo la línea comprada de una dispensa mixta' do
      dispensar(ana, { flor => 10, comprado => 4 })

      expect(g(informe(filtros(origen: 'externo')))).to eq('un' => 4.0)
      expect(g(informe(filtros(origen: 'propio')))).to eq('g' => 10.0)
    end

    it 'por lote: sólo las líneas de ese lote' do
      dispensar(ana, { flor => 10, flor2 => 7 })
      expect(g(informe(filtros(lote_ids: [lote2.id])))).to eq('g' => 7.0)
    end

    it 'por producto: sólo esa forma' do
      dispensar(ana, { flor => 10, comprado => 4 })
      expect(g(informe(filtros(formas: ['preroll'])))).to eq('un' => 4.0)
    end

    it 'el período anterior se filtra igual (la variación compara lo mismo con lo mismo)' do
      dispensar(ana, { flor => 10 })
      Dispensacion.create!(paciente: beto, user: admin, sede: sede, medio_pago: 'efectivo',
                           fecha_dispensacion: 1.month.ago.to_date,
                           items_attributes: [{ stock: flor, cantidad: 50 }])

      x = informe(filtros(paciente_ids: [ana.id]))[:salio][:por_unidad].first
      expect(x[:anterior]).to be_nil
    end
  end
end
