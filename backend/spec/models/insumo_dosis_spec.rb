require 'rails_helper'

# La etiqueta y la medida casera de un nutriente (13-oct-2026): lo que se guarda tiene que poder
# calcularse después (`Nutricion::Dosis`). Lo incompleto se rechaza con el motivo, no se guarda a medias.
RSpec.describe Insumo, 'dosis de la etiqueta' do
  let(:club) { create(:club) }
  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def nutriente(**attrs) = club.insumos.new(nombre: 'Vege', unidad_medida: 'mililitro', tipo: 'cultivo', **attrs)

  it 'con medida casera y su cantidad, y dosis por fase en una unidad conocida: se guarda' do
    i = nutriente(medida_casera: 'Pulso', medida_casera_cantidad: 2, dosis_unidad: 'medida_planta', dosis_vegetativo: 1)
    expect(i).to be_valid
    i.save!
    expect(i.medida_casera).to eq('pulso')
    expect(i.dosis_de('vegetativo')).to eq(1)
    expect(i.dosis_de('floracion')).to be_nil
    expect(i).to be_con_dosis
  end

  it 'una dosis sin unidad, o una unidad desconocida, no' do
    expect(nutriente(dosis_vegetativo: 2)).not_to be_valid
    expect(nutriente(dosis_unidad: 'tapitas', dosis_vegetativo: 2)).not_to be_valid
  end

  it 'dosificar en medidas caseras pide saber cuánto es una' do
    expect(nutriente(medida_casera: 'pulso', dosis_unidad: 'medida_planta', dosis_vegetativo: 1)).not_to be_valid
    expect(nutriente(medida_casera_cantidad: 2)).not_to be_valid # ¿2 qué?
  end

  it 'vacíos del formulario quedan como «sin cargar»' do
    i = nutriente(medida_casera: '', dosis_unidad: '')
    expect(i).to be_valid
    expect([i.medida_casera, i.dosis_unidad]).to eq([nil, nil])
  end

  it 'sin nada cargado, sigue siendo un nutriente válido (es opcional)' do
    expect(nutriente).to be_valid
    expect(nutriente).not_to be_con_dosis
  end
end
