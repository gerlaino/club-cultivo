require 'rails_helper'

# LA CUENTA DE UN FRASCO es lo único de la trazabilidad que un auditor comprueba con lápiz, y
# estaba mal en tres sentidos que no se veían: la dispensa multi-producto contaba la primera línea
# con la suma de todas, las canceladas seguían contando, y el total se sumaba sobre las primeras
# cien. Lo que se fija acá es que cada frasco vea SU parte, que lo que volvió no salió, y que las
# salidas que no son pérdida (traslado, derivado) no se lean como merma.
RSpec.describe Stocks::Trazabilidad do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala, estado: 'curado') }
  let(:paciente) { create(:paciente, club: club, created_by: admin, dni: '30123456') }
  let!(:flor)    { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 100, precio_sugerido_ars: 100) }
  let!(:hash)    { Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'hash',      unidad: 'g', cantidad: 50,  precio_sugerido_ars: 200) }

  def dispensar(items, **extra)
    Dispensacion.create!({ paciente: paciente, user: admin, sede: sede, medio_pago: 'efectivo',
                           fecha_dispensacion: Time.zone.today,
                           items_attributes: items.map { |st, c| { stock: st, cantidad: c } } }.merge(extra))
  end

  def traza(stock, **o) = described_class.new(stock: stock, **o).call

  describe 'a quién fue' do
    it 'una dispensa de dos productos aparece en las DOS cadenas, cada una con su parte' do
      dispensar({ flor => 5, hash => 3 })

      t_flor = traza(flor)
      t_hash = traza(hash)
      expect(t_flor[:totales][:gramos_dispensados]).to eq(5.0)
      expect(t_hash[:totales][:gramos_dispensados]).to eq(3.0)
      expect(t_flor[:dispensaciones].first[:cantidad_g]).to eq(5.0)
      expect(t_flor[:dispensaciones].first[:junto_con]).to eq([hash.numero_lote_producto])
      expect(t_hash[:dispensaciones].size).to eq(1)
    end

    it 'una dispensa cancelada no cuenta: lo que volvió al frasco no salió' do
      d = dispensar({ flor => 5 }, con_envio: true, estado_envio: 'pendiente', direccion_envio: 'Calle 1', contacto_nombre: 'Juan')
      Dispensaciones::Cancelar.new(dispensacion: d, usuario: admin).call

      t = traza(flor)
      expect(t[:dispensaciones]).to be_empty
      expect(t[:totales][:gramos_dispensados]).to eq(0.0)
      expect(t[:totales][:cantidad_disponible_g]).to eq(100.0)
      expect(t[:totales][:sin_explicar_g]).to eq(0.0)
    end

    it 'el total se suma sobre TODAS las entregas aunque la pantalla liste cien' do
      stub_const('Stocks::Trazabilidad::LISTA_PANTALLA', 3)
      5.times { dispensar({ flor => 2 }) }

      t = traza(flor)
      expect(t[:dispensaciones].size).to eq(3)
      expect(t[:dispensaciones_omitidas]).to eq(2)
      expect(t[:totales][:dispensaciones_count]).to eq(5)
      expect(t[:totales][:gramos_dispensados]).to eq(10.0)
      expect(traza(flor, completo: true)[:dispensaciones].size).to eq(5)
    end

    # El DNI entero es dato de salud: sólo en lo que se descarga (decisión de Germán, sep-2026).
    it 'el DNI va parcial en pantalla y completo sólo en el documento' do
      dispensar({ flor => 5 })

      expect(traza(flor)[:dispensaciones].first[:paciente_dni]).to be_nil
      expect(traza(flor)[:dispensaciones].first[:paciente_dni_last3]).to eq('456')
      expect(traza(flor, completo: true)[:dispensaciones].first[:paciente_dni]).to eq('30123456')
    end
  end

  describe 'salió por otro lado' do
    it 'un traslado y un derivado no son merma, y dicen a dónde siguió el producto' do
      otra = Stock.create!(sede: sede, lote: lote, origen: 'lote', forma_producto: 'flor_seca', unidad: 'g', cantidad: 20, precio_sugerido_ars: 100)
      flor.update!(cantidad: 80)
      flor.stock_movimientos.create!(tipo: 'transferencia', gramos: -20, usuario: admin, stock_resultante: otra, sede_destino: sede)
      deriv = Stock.create!(sede: sede, lote: lote, origen: 'derivado_lote', forma_producto: 'hash', unidad: 'g',
                            cantidad: 5, lote_origen_consumido_g: 10, producido_desde_stock: flor, precio_sugerido_ars: 200)
      flor.update!(cantidad: 70)
      flor.stock_movimientos.create!(tipo: 'produccion', gramos: -10, usuario: admin, stock_resultante: deriv)
      flor.update!(cantidad: 68)
      flor.stock_movimientos.create!(tipo: 'merma', gramos: -2, usuario: admin, notas: 'se cayó el frasco')

      t = traza(flor)
      expect(t[:totales][:otras_salidas_g]).to eq(32.0)
      expect(t[:totales][:merma_g]).to eq(2.0)
      expect(t[:totales][:sin_explicar_g]).to eq(0.0)
      expect(t[:siguio_en].map { |x| [x[:tipo], x[:numero]] })
        .to contain_exactly(['traslado', otra.numero_lote_producto], ['derivado', deriv.numero_lote_producto])
      expect(t[:frase]).to include('siguen en', 'se convirtieron en', 'son merma', 'La cuenta cierra.')
    end

    # Un dedazo corregido son dos ajustes que nunca pasaron. Se netean por cierre (Germán, sep-2026).
    it 'los ajustes de conteo de un mismo cierre se netean, y si dan cero no aparecen' do
      turno = ActsAsTenant.with_tenant(club) do
        Mostradores::Cargar.call(mostrador: sede.mostrador!, usuario: admin, motivo: 'x', cambios: [{ stock_id: flor.id, cantidad: 100 }])
        t = Mostradores::AbrirCaja.call(mostrador: sede.mostrador!, usuario: admin, efectivo_contado_ars: 0).turno
        Mostradores::CerrarCaja.call(turno: t, usuario: admin, efectivo_contado_ars: 0, conteos: [{ stock_id: flor.id, contado: 21 }])
        t.reload
      end
      expect(flor.reload.cantidad).to eq(21)
      expect(traza(flor)[:salidas].size).to eq(1)

      item = turno.items.find_by(stock_id: flor.id)
      ActsAsTenant.with_tenant(club) do
        Mostradores::CorregirCierre.call(turno: turno, usuario: admin, motivo: 'me comí un dígito', causa: 'error_conteo',
                                         conteos: [{ item_id: item.id, contado: 100 }])
      end
      expect(flor.reload.cantidad).to eq(100)
      t = traza(flor)
      expect(t[:salidas]).to be_empty
      expect(t[:totales][:sin_explicar_g]).to eq(0.0)
      expect(t[:frase]).to include('La cuenta cierra.')
    end

    it 'lo que ningún movimiento explica se dice, y la cuenta no cierra' do
      flor.update!(cantidad: 90) # bajó sin movimiento ni dispensa

      t = traza(flor)
      expect(t[:totales][:sin_explicar_g]).to eq(10.0)
      expect(t[:frase]).to include('Faltan 10 g que ningún movimiento explica')
    end
  end

  describe 'la cadena' do
    # Lo que le pusieron a la planta también está en el hash (decisión de Germán, sep-2026).
    it 'un derivado hereda el lote y dice de qué frasco salió' do
      deriv = Stock.create!(sede: sede, lote: lote, origen: 'derivado_lote', forma_producto: 'hash', unidad: 'g',
                            cantidad: 5, lote_origen_consumido_g: 10, producido_desde_stock: flor, precio_sugerido_ars: 200)

      t = traza(deriv)
      expect(t[:lote][:codigo]).to eq(lote.codigo)
      expect(t[:stock][:producido_desde]).to include(numero: flor.numero_lote_producto, gramos: 10.0)
      expect(t[:frase]).to include("de 10 g de #{flor.numero_lote_producto}")
    end

    it 'las plantas van con su nombre, que es con lo que se las nombra' do
      create(:plant, lote: lote, club: club, nombre: 'L-X-P001', state: 'cosechado')
      expect(traza(flor)[:plantas].first[:nombre]).to eq('L-X-P001')
    end

    it 'un stock comprado afuera tiene proveedor y no lote' do
      ext = Stock.create!(sede: sede, origen: 'compra_externa', proveedor: 'Lab Sur', forma_producto: 'aceite',
                          unidad: 'ml', cantidad: 30, precio_sugerido_ars: 500)
      t = traza(ext)
      expect(t[:lote]).to be_nil
      expect(t[:stock][:proveedor]).to eq('Lab Sur')
      expect(t[:frase]).to include('comprados a Lab Sur')
    end

    # La pantalla dibujaba `lote_eventos`, que el backend nunca mandó: la cronología mostró sólo
    # la pesada durante meses.
    it 'la cronología trae los cambios de estado con los días del anterior' do
      lote.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'vegetativo', club: club, user: admin, registrado_en: 60.days.ago)
      lote.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'vegetativo', estado_nuevo: 'floracion', club: club, user: admin, registrado_en: 25.days.ago)

      c = traza(flor)[:cronologia]
      expect(c.map { |i| i[:estado] }).to eq(%w[vegetativo floracion])
      expect(c.last[:detalle]).to eq('35 días en vegetativo')
    end
  end

  it 'no ve dispensas de otra organización' do
    otro_club = create(:club)
    otro_admin = create(:user, :admin, club: otro_club)
    ActsAsTenant.with_tenant(otro_club) do
      otra_sede = create(:sede, club: otro_club, created_by: otro_admin)
      otro_pac  = create(:paciente, club: otro_club, created_by: otro_admin)
      otro_st   = Stock.create!(sede: otra_sede, origen: 'compra_externa', proveedor: 'X', forma_producto: 'aceite', unidad: 'ml', cantidad: 30, precio_sugerido_ars: 1)
      Dispensacion.create!(paciente: otro_pac, user: otro_admin, sede: otra_sede, medio_pago: 'efectivo',
                           fecha_dispensacion: Time.zone.today, items_attributes: [{ stock: otro_st, cantidad: 1 }])
    end
    expect(traza(flor)[:dispensaciones]).to be_empty
  end
end
