require 'rails_helper'

# Un derivado puede tener MÁS unidades que gramos consumidos, y eso no es un error: de 100 g de
# flor salen 200 prerolls de medio gramo, o 400 cápsulas. El número es mayor porque la unidad es
# otra.
#
# El tope contra la materia que aparece de la nada —de 100 g de flor no pueden salir 120 g de
# hash— sigue en pie, pero sólo donde tiene sentido: cuando el resultado se mide en gramos.
RSpec.describe Stock, 'derivados medidos en otra unidad' do
  let(:club) { create(:club) }
  let(:sede) { create(:sede, club: club, tipo: 'social') }
  let(:lote) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) }

  def derivado(forma:, unidad:, cantidad:, consumidos: 100)
    ActsAsTenant.with_tenant(club) do
      # La flor de la que sale el derivado: sin ella el descuento del lote origen aborta.
      Stock.find_or_create_by!(club: club, sede: sede, lote: lote, origen: 'lote',
                               forma_producto: 'flor_seca') do |s|
        s.unidad = 'g'; s.cantidad = 500; s.estado = 'asignado'; s.disponibilidad = 'ambas'
      end
      Stock.new(club: club, sede: sede, lote: lote, origen: 'derivado_lote',
                forma_producto: forma, unidad: unidad, cantidad: cantidad,
                lote_origen_consumido_g: consumidos, estado: 'asignado', disponibilidad: 'ambas')
    end
  end

  it 'de 100 g salen 200 prerolls' do
    expect(derivado(forma: 'preroll', unidad: 'un', cantidad: 200)).to be_valid
  end

  it 'de 100 g salen 400 cápsulas' do
    expect(derivado(forma: 'capsula', unidad: 'un', cantidad: 400)).to be_valid
  end

  it 'de 100 g salen 300 ml de tintura' do
    expect(derivado(forma: 'tintura', unidad: 'ml', cantidad: 300)).to be_valid
  end

  it 'de 100 g NO salen 120 g de hash: eso sigue rechazado' do
    d = derivado(forma: 'hash', unidad: 'g', cantidad: 120)

    expect(d).not_to be_valid
    expect(d.errors[:cantidad].join).to match(/no puede superar los gramos consumidos/)
  end

  it 'de 100 g sí salen 18 g de hash' do
    expect(derivado(forma: 'hash', unidad: 'g', cantidad: 18)).to be_valid
  end
end
