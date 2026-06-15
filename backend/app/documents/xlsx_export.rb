require "caxlsx"

# Generador de exportaciones a Excel (.xlsx) con membrete del club y encabezados
# con formato. Reutilizable por cualquier informe tabular.
#
#   XlsxExport.new(
#     club:    club,
#     titulo:  "Informe REPROCANN",
#     headers: ["Col A", "Col B"],
#     rows:    [["1", "2"], ["3", "4"]],
#     anchos:  [20, 40],
#   ).render  # => String (bytes .xlsx)
class XlsxExport
  def initialize(club:, titulo:, headers:, rows:, anchos: nil, hoja: nil)
    @club    = club
    @titulo  = titulo
    @headers = headers
    @rows    = rows
    @anchos  = anchos
    @hoja    = (hoja || titulo).to_s.gsub(/[\[\]\*\/\\\?:]/, " ")[0, 30]
  end

  def render
    package = Axlsx::Package.new
    wb = package.workbook

    s_titulo = wb.styles.add_style(b: true, sz: 14, fg_color: "0F3D20")
    s_sub    = wb.styles.add_style(sz: 9,  fg_color: "64748B")
    s_header = wb.styles.add_style(
      b: true, sz: 10, fg_color: "FFFFFF", bg_color: "15803D",
      alignment: { horizontal: :left, vertical: :center }, border: { style: :thin, color: "FFFFFF" },
    )
    s_cell   = wb.styles.add_style(sz: 10, border: { style: :thin, color: "E2E8F0" })

    wb.add_worksheet(name: @hoja) do |sheet|
      sheet.add_row [@club.name], style: s_titulo
      sheet.add_row ["#{@titulo} · Emitido el #{Time.current.strftime('%d/%m/%Y %H:%M')}"], style: s_sub
      sheet.add_row [datos_legales], style: s_sub if datos_legales.present?
      sheet.add_row []
      sheet.add_row @headers, style: s_header
      @rows.each { |r| sheet.add_row r, style: s_cell }
      sheet.column_widths(*@anchos) if @anchos
    end

    package.to_stream.read
  end

  private

  def datos_legales
    partes = []
    partes << "CUIT #{@club.cuit}" if @club.respond_to?(:cuit) && @club.cuit.present?
    if @club.respond_to?(:numero_resolucion_reprocann) && @club.numero_resolucion_reprocann.present?
      partes << "Res. REPROCANN #{@club.numero_resolucion_reprocann}"
    end
    partes.join("   ·   ")
  end
end
