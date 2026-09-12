require 'rails_helper'

# EL INFORME DE DISPENSACIONES CUENTA POR LÍNEA Y POR UNIDAD. Sumaba `dispensaciones.cantidad`
# —la suma de todas las líneas en la unidad de cada una: 12 prerolls entraban como 12 gramos— y
# leía genética y producto de `stock_id`, la primera línea. Lo que se fija acá: cada unidad en lo
# suyo, cada línea en su producto, la lista de pacientes completa, y las decisiones de Germán
# (sep-2026): los regalos cuentan y se dicen, «nuevo» es primera vez en la organización, un envío
# que no llegó cuenta y la fila lo dice.
RSpec.describe Informes::Dispensaciones do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin, tipo: 'mixta', nombre: 'Centro') }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:critical) { create(:genetica, club: club, nombre: 'Critical Kush') }
  let(:northern) { create(:genetica, club: club, nombre: 'Northern Lights') }
  let(:lote)     { create(:lote, club: club, sala: sala, genetica: critical) }
  let(:ana)      { create(:paciente, club: club, created_by: admin, dni: '30111222') }
  let(:beto)     { create(:paciente, club: club, created_by: admin, dni: '30111333') }
  let!(:flor)    { Stock.create!(sede: sede, lote: lote, origen: 'lote', genetica: critical, forma_producto: 'flor_seca', unidad: 'g',  cantidad: 1000, precio_sugerido_ars: 100) }
  let!(:preroll) { Stock.create!(sede: sede, lote: lote, origen: 'lote', genetica: northern, forma_producto: 'preroll',   unidad: 'un', cantidad: 200,  precio_sugerido_ars: 500) }

  let(:desde) { Time.zone.today.beginning_of_month.beginning_of_day }
  let(:hasta) { Time.zone.today.end_of_month.end_of_day }

  def informe(d = desde, h = hasta) = described_class.new(club: club, desde: d, hasta: h).call

  def dispensar(paciente, items, fecha: Time.zone.today, **extra)
    Dispensacion.create!({ paciente: paciente, user: admin, sede: sede, medio_pago: 'efectivo',
                           fecha_dispensacion: fecha,
                           items_attributes: items.map { |st, c| { stock: st, cantidad: c } } }.merge(extra))
  end

  it 'los prerolls no suman gramos: cada unidad en lo suyo' do
    dispensar(ana, { flor => 10, preroll => 12 })

    u = informe[:salio][:por_unidad].to_h { |x| [x[:unidad], x[:cantidad]] }
    expect(u).to eq('g' => 10.0, 'un' => 12.0)
  end

  it 'una dispensa de dos productos aparece en las dos filas de producto, y el paciente con las dos genéticas' do
    dispensar(ana, { flor => 10, preroll => 12 })

    prods = informe[:productos]
    expect(prods.map { |f| f[:forma] }).to contain_exactly('flor_seca', 'preroll')
    expect(prods.find { |f| f[:forma] == 'preroll' }[:geneticas].first).to include(genetica: 'Northern Lights', cantidad: 12.0)
    expect(informe[:pacientes].first[:geneticas]).to contain_exactly('Critical Kush', 'Northern Lights')
  end

  it 'compara con el período anterior de la misma duración' do
    dispensar(ana, { flor => 10 })
    dispensar(ana, { flor => 20 }, fecha: 1.month.ago.to_date)

    g = informe[:salio][:por_unidad].find { |x| x[:unidad] == 'g' }
    expect(g[:anterior]).to eq(20.0)
    expect(g[:variacion]).to eq(-50.0)
  end

  it 'la lista de pacientes es COMPLETA y ordenada por lo que retiraron' do
    stub_const('Informes::Dispensaciones::LISTA_PANTALLA', 1)
    dispensar(ana, { flor => 5 })
    dispensar(beto, { flor => 30 })

    pacs = informe[:pacientes]
    expect(pacs.size).to eq(2)
    expect(pacs.first[:paciente]).to eq(beto.nombre_completo)
    expect(pacs.first[:dni]).to eq('30111333')
  end

  # Decisión de Germán: los regalos siguen contando, y se dicen aparte.
  it 'los regalos cuentan y se dicen aparte' do
    dispensar(ana, { flor => 10 })
    dispensar(beto, { flor => 4 }, es_regalo: true, medio_pago: 'regalo')

    s = informe[:salio]
    expect(s[:por_unidad].find { |x| x[:unidad] == 'g' }[:cantidad]).to eq(14.0)
    expect(s[:regalos]).to eq([{ unidad: 'g', cantidad: 4.0 }])
    expect(s[:regalos_entregas]).to eq(1)
  end

  # «Nuevo» es primera vez en la ORGANIZACIÓN, no en el período.
  it 'cuenta como nuevo al que retira por primera vez en la organización' do
    dispensar(ana, { flor => 10 }, fecha: 3.months.ago.to_date)
    dispensar(ana, { flor => 10 })
    dispensar(beto, { flor => 10 })

    expect(informe[:salio][:nuevos]).to eq(1)
  end

  it 'separa el mostrador de cada sede del envío, y dice cuántos envíos no llegaron' do
    dispensar(ana, { flor => 10 })
    dispensar(beto, { flor => 5 }, con_envio: true, estado_envio: 'en_viaje', direccion_envio: 'Calle 1', contacto_nombre: 'Beto')
    dispensar(beto, { flor => 5 }, con_envio: true, direccion_envio: 'Calle 1', contacto_nombre: 'Beto').update_column(:estado_envio, 'entregado')

    canales = informe[:canales]
    expect(canales.map { |c| c[:canal] }).to eq(['Mostrador · Centro', 'Envío a domicilio'])
    envio = canales.last
    expect(envio[:entregas]).to eq(2)
    expect(envio[:sin_llegar]).to eq(1)
  end

  it 'una cancelada no cuenta' do
    d = dispensar(ana, { flor => 10 }, con_envio: true, estado_envio: 'pendiente', direccion_envio: 'Calle 1', contacto_nombre: 'Ana')
    Dispensaciones::Cancelar.new(dispensacion: d, usuario: admin).call

    expect(informe[:salio][:entregas][:valor]).to eq(0)
  end

  it 'no ve dispensas de otra organización' do
    otro = create(:club)
    otro_admin = create(:user, :admin, club: otro)
    ActsAsTenant.with_tenant(otro) do
      s = create(:sede, club: otro, created_by: otro_admin, tipo: 'mixta')
      st = Stock.create!(sede: s, origen: 'compra_externa', proveedor: 'X', forma_producto: 'aceite', unidad: 'ml', cantidad: 30, precio_sugerido_ars: 1)
      Dispensacion.create!(paciente: create(:paciente, club: otro, created_by: otro_admin), user: otro_admin, sede: s,
                           medio_pago: 'efectivo', fecha_dispensacion: Time.zone.today, items_attributes: [{ stock: st, cantidad: 1 }])
    end

    expect(informe[:salio][:entregas][:valor]).to eq(0)
  end
end
