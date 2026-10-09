# Informe genérico en PDF: franja de indicadores + una o más tablas.
#
# Existe porque seis de los siete informes generaban su PDF con html2canvas, o sea una FOTO
# JPEG de la pantalla: sin texto seleccionable ni buscable, con la calidad atada al zoom del
# navegador y las columnas cortadas donde cayera. Un informe que se presenta ante un auditor
# no puede ser una captura de pantalla.
#
#   InformeDocument.new(
#     club: club, usuario: user, titulo: "Dispensaciones",
#     periodo: "Agosto 2026",
#     kpis: [{ label: "Entregas", valor: 42 }, { label: "Gramos", valor: "1.240 g", tono: :ok }],
#     secciones: [
#       { titulo: "Detalle", headers: %w[A B], rows: [[1, 2]], aligns: { 1 => :right } },
#     ],
#   ).render
class InformeDocument < BaseDocument
  # Ancho útil de la caja en A4 vertical con los márgenes de BaseDocument. Las columnas
  # tienen que sumar exactamente esto: Prawn no acepta ni de más ni de menos.
  # `filtros`: qué recorte se pidió («Lotes: L-26-001 · sólo lo comprado»). Va debajo del período,
  # en negrita: un informe filtrado que no lo dice se lee como el total de la organización.
  def initialize(club:, usuario:, titulo:, secciones:, kpis: nil, periodo: nil, nota: nil,
                 tipo_code: "INF", salvedad_inase: nil, filtros: nil, apaisado: false)
    @kpis      = kpis
    @secciones = secciones
    @periodo   = periodo
    @nota      = nota
    @filtros   = filtros
    super(club: club, usuario: usuario, titulo: titulo,
          tipo_doc: titulo, tipo_code: tipo_code, salvedad_inase: salvedad_inase, apaisado: apaisado)
  end

  def cuerpo(pdf)
    if @periodo.present?
      pdf.fill_color GRAY
      pdf.font(SANS) { pdf.text "Período: #{@periodo}", size: 9 }
      pdf.fill_color INK
      pdf.move_down 8
    end

    if @filtros.present?
      pdf.font(SANS) { pdf.text "Filtrado — #{@filtros}", size: 9, style: :bold }
      pdf.move_down 8
    end

    if @kpis.present?
      titulo_seccion(pdf, "Resumen")
      stat_strip(pdf, @kpis)
    end

    Array(@secciones).each do |sec|
      titulo_seccion(pdf, sec[:titulo]) if sec[:titulo].present?
      if sec[:rows].blank?
        pdf.fill_color GRAY
        pdf.font(SANS) { pdf.text sec[:vacio] || "Sin datos para el período elegido.", size: 9 }
        pdf.fill_color INK
        pdf.move_down 10
        next
      end
      styled_table(pdf, sec[:headers], sec[:rows].map { |r| r.map(&:to_s) },
                   col_widths: anchos(pdf, sec), aligns: sec[:aligns] || {}, fila_total: sec[:fila_total])
      pdf.move_down 6
    end

    return if @nota.blank?

    pdf.move_down 6
    pdf.fill_color GRAY
    pdf.font(SANS) { pdf.text @nota, size: 7.5 }
    pdf.fill_color INK
  end

  private

  # Reparte el ancho disponible: la primera columna (la que lleva texto) se queda con el
  # sobrante y las demás van fijas. Calcularlo en runtime evita tener que reajustar números
  # a mano si cambian los márgenes.
  # `col_min` deja que una sección pida un ancho mínimo para una columna concreta.
  #
  # Existe por el DNI: con el documento completo en los informes que se PRESENTAN, ocho dígitos
  # en una tabla de siete columnas se partían en dos líneas ("301112 / 22"), y un número de
  # documento cortado en algo que va a un organismo se puede leer mal. El sobrante sale de la
  # primera columna, que es la de texto libre y tiene de dónde.
  def anchos(pdf, sec)
    return sec[:col_widths] if sec[:col_widths]
    return anchos_por_contenido(pdf, sec) if sec[:anchos] == :contenido

    n = sec[:headers].size
    return { 0 => pdf.bounds.width } if n == 1

    fija    = [(pdf.bounds.width * 0.62 / (n - 1)), 46].min
    minimos = sec[:col_min] || {}
    cols    = (1...n).to_h { |i| [i, [fija, minimos[i].to_f].max] }
    { 0 => pdf.bounds.width - cols.values.sum }.merge(cols)
  end

  # Para los listados (`DescargaProfesional`). Primero, que ninguna palabra se corte: cada columna
  # arranca con el ancho de su palabra más larga (encabezado incluido) —«Priorid/ad» o un «41/2» en
  # una celda de gramos se leen mal—. Lo que sobra se reparte según lo que lleva cada columna (el
  # largo típico de sus celdas, no el récord: una nota larga no se come la tabla). Si ni así entra,
  # se achica todo parejo.
  ANCHO_LETRA = 5.4 # pt por carácter a 8,5 pt, con margen para mayúsculas y negrita
  RELLENO     = 15  # padding de la celda, a los dos lados

  def anchos_por_contenido(pdf, sec)
    total = pdf.bounds.width
    n = sec[:headers].size
    palabra = ->(t) { t.to_s.split(/\s+/).map(&:length).max.to_i }
    minimos = (0...n).map do |i|
      larga = ([palabra.(sec[:headers][i])] + sec[:rows].map { |r| palabra.(r[i]) }).max
      [larga, 2].max * ANCHO_LETRA + RELLENO
    end
    pesos = (0...n).map do |i|
      largos = sec[:rows].map { |r| r[i].to_s.length }.sort
      tipico = largos.empty? ? 0 : largos[(largos.size * 0.9).floor.clamp(0, largos.size - 1)]
      [tipico, sec[:headers][i].to_s.length].max.clamp(1, 60)
    end
    base = minimos.sum
    anchos = if base >= total
               minimos.map { |m| m * total / base }
             else
               sobra = total - base
               minimos.each_with_index.map { |m, i| m + sobra * pesos[i] / pesos.sum.to_f }
             end
    anchos.each_with_index.to_h { |a, i| [i, a] }
  end
end
