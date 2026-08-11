require 'rails_helper'

# Lo que puede salir mal —y arruinar el nombre de una persona real— no es el recorrido de la
# tabla sino el caso raro: una partícula, un apóstrofo, un acento que no hay que inventar.
RSpec.describe Pacientes::NormalizarNombre do
  def n(texto) = described_class.call(texto)

  it 'arregla el APELLIDO EN MAYÚSCULAS que devuelve el listado de REPROCANN' do
    expect(n('BLANCO')).to eq('Blanco')
    expect(n('CARLINO CURRENTI')).to eq('Carlino Currenti')
  end

  it 'arregla las minúsculas de las altas a mano' do
    expect(n('ana maria')).to eq('Ana Maria')
  end

  it 'deja intacto lo que ya está bien, acentos incluidos' do
    expect(n('Ana Pérez')).to eq('Ana Pérez')
    expect(n('Nicolás')).to eq('Nicolás')
  end

  # No inventa acentos: hay Perez sin tilde, y ponérsela es cambiarle el apellido a alguien.
  it 'no agrega acentos que no estaban' do
    expect(n('PEREZ')).to eq('Perez')
  end

  it 'deja las partículas en minúscula, salvo cuando abren el apellido' do
    expect(n('JUANA DE ARCO')).to eq('Juana de Arco')
    expect(n('DE LUCA')).to eq('De Luca')
    expect(n('della valle')).to eq('Della Valle')
  end

  it 'respeta la mayúscula interna de los apellidos que la llevan' do
    expect(n("O'BRIEN")).to eq("O'Brien")
    expect(n('MCDONALD')).to eq('McDonald')
    expect(n("d'angelo")).to eq("D'Angelo")
  end

  it 'capitaliza los dos lados de un apellido con guion' do
    expect(n('GARCIA-LOPEZ')).to eq('Garcia-Lopez')
  end

  it 'limpia los espacios de más de los copiados' do
    expect(n('  ANA   MARIA  ')).to eq('Ana Maria')
  end

  it 'no rompe con nil ni con vacío' do
    expect(n(nil)).to be_nil
    expect(n('')).to eq('')
  end
end
