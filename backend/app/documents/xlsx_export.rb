require "caxlsx"

# Generador de exportaciones a Excel (.xlsx) con membrete del club, encabezados con formato,
# tipos de dato reales y fila de totales. Reutilizable por cualquier informe tabular.
#
# El punto de tener tipos y no todo texto: un Excel donde los montos son strings no se puede
# sumar, ordenar ni filtrar — que es exactamente para lo que alguien se baja un Excel.
#
#   XlsxExport.new(
#     club:    club,
#     titulo:  "Movimientos contables",
#     headers: ["Fecha", "Descripción", "Monto"],
#     rows:    [[Date.today, "Alquiler", -45000]],
#     formatos: [:fecha, :texto, :moneda],   # opcional, por columna
#     totales:  [2],                          # opcional: índices de columna a sumar
#     resumen:  { "Ingresos" => 120_000, "Egresos" => -45_000 },  # opcional
#   ).render  # => String (bytes .xlsx)
class XlsxExport
  ANCHO_MIN = 10
  ANCHO_MAX = 55

  def initialize(club:, titulo:, headers:, rows:, anchos: nil, hoja: nil,
                 formatos: nil, totales: nil, resumen: nil, subtitulo: nil)
    @club      = club
    @titulo    = titulo
    @headers   = headers
    @rows      = rows
    @anchos    = anchos
    @formatos  = formatos
    @totales   = Array(totales)
    @resumen   = resumen
    @subtitulo = subtitulo
    @hoja      = (hoja || titulo).to_s.gsub(/[\[\]\*\/\\\?:]/, " ")[0, 30]
  end

  def render
    package = Axlsx::Package.new
    wb = package.workbook
    e = estilos(wb)

    wb.add_worksheet(name: @hoja) do |sheet|
      encabezado(sheet, e)
      resumen(sheet, e)   if @resumen.present?

      fila_headers = sheet.rows.size
      sheet.add_row @headers, style: e[:header]
      @rows.each { |r| sheet.add_row r, style: estilos_de_fila(e) }
      totales(sheet, e)   if @totales.any? && @rows.any?

      # Filtros y panel fijo: en una tabla de cientos de filas es la diferencia entre poder
      # trabajarla y tener que exportarla de nuevo a otro lado.
      sheet.auto_filter = "A#{fila_headers + 1}:#{Axlsx.col_ref(@headers.size - 1)}#{sheet.rows.size}"
      sheet.sheet_view.pane { |p| p.top_left_cell = "A#{fila_headers + 2}"; p.state = :frozen; p.y_split = fila_headers + 1 }
      sheet.column_widths(*(@anchos || anchos_automaticos))
    end

    package.to_stream.read
  end

  private

  def estilos(wb)
    borde = { style: :thin, color: "E2E8F0" }
    {
      titulo:  wb.styles.add_style(b: true, sz: 14, fg_color: "0F3D20"),
      sub:     wb.styles.add_style(sz: 9, fg_color: "64748B"),
      header:  wb.styles.add_style(b: true, sz: 10, fg_color: "FFFFFF", bg_color: "15803D",
                                   alignment: { horizontal: :left, vertical: :center },
                                   border: { style: :thin, color: "FFFFFF" }),
      texto:   wb.styles.add_style(sz: 10, border: borde),
      moneda:  wb.styles.add_style(sz: 10, border: borde, format_code: '"$"#,##0.00;[Red]-"$"#,##0.00'),
      numero:  wb.styles.add_style(sz: 10, border: borde, format_code: '#,##0.##'),
      fecha:   wb.styles.add_style(sz: 10, border: borde, format_code: 'dd/mm/yyyy'),
      rot_res: wb.styles.add_style(b: true, sz: 10, fg_color: "334155"),
      val_res: wb.styles.add_style(b: true, sz: 11, format_code: '"$"#,##0.00;[Red]-"$"#,##0.00'),
      tot_lbl: wb.styles.add_style(b: true, sz: 10, bg_color: "F1F5F9", border: borde),
      tot_val: wb.styles.add_style(b: true, sz: 10, bg_color: "F1F5F9", border: borde,
                                   format_code: '"$"#,##0.00;[Red]-"$"#,##0.00'),
    }
  end

  def encabezado(sheet, e)
    sheet.add_row [@club.name], style: e[:titulo]
    sheet.add_row ["#{@titulo} · Emitido el #{Time.current.strftime('%d/%m/%Y %H:%M')}"], style: e[:sub]
    sheet.add_row [@subtitulo], style: e[:sub] if @subtitulo.present?
    sheet.add_row [datos_legales], style: e[:sub] if datos_legales.present?
    sheet.add_row []
  end

  # Los números que importan, arriba y a la vista, antes de la tabla.
  def resumen(sheet, e)
    @resumen.each { |rot, val| sheet.add_row [rot, val], style: [e[:rot_res], e[:val_res]] }
    sheet.add_row []
  end

  def totales(sheet, e)
    fila = Array.new(@headers.size)
    fila[0] = "TOTAL (#{@rows.size} #{@rows.size == 1 ? 'fila' : 'filas'})"
    estilos_fila = Array.new(@headers.size, e[:tot_lbl])
    @totales.each do |i|
      fila[i] = @rows.sum { |r| r[i].to_f }
      estilos_fila[i] = e[:tot_val]
    end
    sheet.add_row fila, style: estilos_fila
  end

  def estilos_de_fila(e)
    return e[:texto] if @formatos.blank?
    @formatos.map { |f| e[f] || e[:texto] }
  end

  # Ancho por el contenido más largo de cada columna, acotado para que una nota kilométrica
  # no deje una columna de 300 caracteres.
  def anchos_automaticos
    @headers.each_with_index.map do |h, i|
      largo = ([h.to_s.length] + @rows.map { |r| r[i].to_s.length }).max.to_i
      largo.clamp(ANCHO_MIN, ANCHO_MAX)
    end
  end

  def datos_legales
    partes = []
    partes << "CUIT #{@club.cuit}" if @club.respond_to?(:cuit) && @club.cuit.present?
    if @club.respond_to?(:numero_resolucion_reprocann) && @club.numero_resolucion_reprocann.present?
      partes << "Res. REPROCANN #{@club.numero_resolucion_reprocann}"
    end
    partes.join("   ·   ")
  end
end
