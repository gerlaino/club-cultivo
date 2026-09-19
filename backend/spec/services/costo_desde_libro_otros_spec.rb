require 'rails_helper'

# Un gasto «para un lote» que no es insumo, energía ni mano de obra —la lámpara, la carpa, un
# tipo que creó el usuario— tiene que entrar al costo del lote igual. Caía en `otro` y no se
# sumaba a nada: el costo por gramo salía sin él y nadie se enteraba.
RSpec.describe CostoDesdeLibroService do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club) }
  let(:lote)  { create(:lote, club: club, sede: sede, sala: create(:sala, club: club, sede: sede)) }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def gasto(categoria, monto, cat_contable: nil)
    club.movimientos_contables.create!(tipo: 'egreso', categoria: categoria, categoria_contable: cat_contable,
                                       descripcion: categoria || 'gasto', monto_ars: monto, fecha: Time.zone.today,
                                       lote: lote, created_by: admin, pagado: true)
  end

  it 'suma a «otros» lo que no cae en insumos, energía ni mano de obra' do
    gasto('insumo', 1000)
    gasto('electricidad', 500)
    gasto('otro', 3000)      # una lámpara
    gasto('alquiler', 2000)  # el cuarto

    costo = described_class.new(lote: lote).call
    expect(costo.costo_insumos.to_f).to eq(1000)
    expect(costo.costo_energia.to_f).to eq(500)
    expect(costo.costo_otros.to_f).to eq(5000)
    expect(costo.costo_total.to_f).to eq(6500)
  end

  it 'un tipo creado por el usuario (sin clave) también entra' do
    sector = club.unidades_negocio.create!(nombre: 'Cultivo', tipo: 'cultivo', es_sistema: true)
    cat = club.categorias_contables.create!(nombre: 'Carpa', tipo: 'egreso', comportamiento: 'general', unidad_negocio: sector)
    gasto(nil, 4500, cat_contable: cat) # la categoría se deriva de la contable → 'otro'

    costo = described_class.new(lote: lote).call
    expect(costo.costo_otros.to_f).to eq(4500)
    expect(costo.costo_total.to_f).to eq(4500)
  end

  it 'no cuenta movimientos de caja ni ingresos aunque traigan lote' do
    gasto('otro', 100)
    club.movimientos_contables.create!(tipo: 'ajuste', categoria: 'retiro_caja', descripcion: 'x', monto_ars: 9999,
                                       fecha: Time.zone.today, lote: lote, created_by: admin, retirado_por: admin) rescue nil

    costo = described_class.new(lote: lote).call
    expect(costo.costo_otros.to_f).to eq(100)
  end
end
