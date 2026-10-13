require 'rails_helper'

# La única cuenta entre «lo que se dijo» y lo que sale del depósito (Germán, 13-oct-2026: «un
# pulso a cada planta, tenés que poder calcular»).
RSpec.describe Nutricion::Dosis do
  around { |ej| ActsAsTenant.with_tenant(create(:club)) { ej.run } }

  let(:vege)   { Insumo.new(nombre: 'Vege', unidad_medida: 'mililitro', medida_casera: 'pulso', medida_casera_cantidad: 2) }
  let(:bidon)  { Insumo.new(nombre: 'Base A', unidad_medida: 'litro') }
  let(:harina) { Insumo.new(nombre: 'Harina', unidad_medida: 'kilogramo', medida_casera: 'cucharada', medida_casera_cantidad: 15) }

  def calc(insumo, **kw) = described_class.calcular(insumo: insumo, **kw)

  it 'un pulso a cada planta: pulsos × plantas × lo que es un pulso' do
    r = calc(vege, valor: 1, medida: 'medida', por: 'planta', plantas: 6)
    expect(r.cantidad).to eq(12) # 1 pulso (2 ml) × 6 plantas
    expect(r.detalle).to eq('1 pulso × 6 plantas')
  end

  it 'ml por litro: dosis × litros' do
    r = calc(vege, valor: 2, medida: 'ml', por: 'litro', litros: 3)
    expect(r.cantidad).to eq(6)
    expect(r.detalle).to eq('2 ml × 3 L')
  end

  it 'convierte a la unidad en que vive el nutriente (un bidón en litros, una bolsa en kg)' do
    expect(calc(bidon, valor: 2, medida: 'ml', por: 'litro', litros: 5).cantidad).to eq(BigDecimal('0.01'))
    expect(calc(harina, valor: 2, medida: 'medida', por: 'total').cantidad).to eq(BigDecimal('0.03')) # 30 g
  end

  it 'lo que no se puede calcular no se adivina: dice qué falta' do
    expect(calc(vege, valor: 2, medida: 'ml', por: 'litro').falta).to eq('litros')
    expect(calc(vege, valor: 1, medida: 'medida', por: 'planta', plantas: 0).falta).to eq('plantas')
    expect(calc(bidon, valor: 1, medida: 'medida', por: 'total').falta).to eq('medida')
    expect(calc(vege, valor: 0, medida: 'ml').falta).to eq('valor')
  end

  it 'la unidad guardada en el nutriente se parte en qué y por cada qué' do
    expect(described_class.partes_de('medida_planta')).to eq(%w[medida planta])
    expect(described_class.partes_de('ml_litro')).to eq(%w[ml litro])
  end
end
