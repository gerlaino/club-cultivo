require 'rails_helper'

# AC: un Excel donde los montos son texto no se puede sumar, ordenar ni filtrar — que es
# justo para lo que alguien se baja un Excel. Germán: "descargué el informe de contabilidad
# y el excel estaba todo feo, sin tablas armadas".
RSpec.describe XlsxExport do
  let(:club) { create(:club, name: 'Club Uno') }

  # Axlsx escribe los textos INLINE en la hoja (no usa xl/sharedStrings.xml), así que todo
  # —membrete incluido— se busca en el XML de la hoja.
  def hoja(bytes)
    Zip::File.open_buffer(bytes) { |z| return z.read('xl/worksheets/sheet1.xml') }
  end

  def exportar(**extra)
    described_class.new(
      club: club, titulo: 'Movimientos',
      headers: %w[Fecha Descripción Monto],
      rows: [[Time.zone.today, 'Alquiler', -45_000.0], [Time.zone.today, 'Aporte', 12_000.0]],
      **extra
    ).render
  end

  it 'genera un archivo xlsx válido' do
    bytes = exportar

    expect(bytes).to be_present
    expect(bytes[0, 2]).to eq('PK') # firma de un zip, que es lo que es un .xlsx
  end

  it 'los montos van como NÚMERO, no como texto' do
    xml = hoja(exportar(formatos: [:fecha, :texto, :moneda]))

    # Una celda de texto en xlsx lleva t="s" (shared string). Un número no lleva `t`.
    expect(xml).to include('-45000')
    expect(xml).not_to match(/<c[^>]*t="s"[^>]*><v>[^<]*-45000/)
  end

  it 'suma una fila de totales sobre las columnas pedidas' do
    xml = hoja(exportar(formatos: [:fecha, :texto, :moneda], totales: [2]))

    expect(xml).to include('-33000') # -45000 + 12000
  end

  it 'pone los números que importan arriba, antes de la tabla' do
    xml = hoja(exportar(resumen: { 'Ingresos' => 12_000.0, 'Resultado' => -33_000.0 }))

    expect(xml).to include('Ingresos')
    expect(xml).to include('Resultado')
    # El resumen va ANTES de los encabezados de la tabla. (El XML viene en ASCII-8BIT, así
    # que se compara contra un rótulo sin acentos.)
    expect(xml.index('Ingresos')).to be < xml.index('Monto')
  end

  it 'lleva el membrete del club' do
    expect(hoja(exportar)).to include('Club Uno')
  end

  # Sin filtros ni panel fijo, una tabla de cientos de filas obliga a rearmarla en otro lado.
  it 'deja la tabla filtrable y con los encabezados fijos' do
    xml = hoja(exportar)

    expect(xml).to include('autoFilter')
    expect(xml).to include('frozen')
  end

  it 'no explota sin filas' do
    bytes = described_class.new(club: club, titulo: 'Vacío', headers: %w[A B], rows: []).render

    expect(bytes[0, 2]).to eq('PK')
  end
end
