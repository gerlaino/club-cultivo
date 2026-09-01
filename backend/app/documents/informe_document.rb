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
  def initialize(club:, usuario:, titulo:, secciones:, kpis: nil, periodo: nil, nota: nil,
                 tipo_code: "INF")
    @kpis      = kpis
    @secciones = secciones
    @periodo   = periodo
    @nota      = nota
    super(club: club, usuario: usuario, titulo: titulo,
          tipo_doc: titulo, tipo_code: tipo_code)
  end

  def cuerpo(pdf)
    if @periodo.present?
      pdf.fill_color GRAY
      pdf.font(SANS) { pdf.text "Período: #{@periodo}", size: 9 }
      pdf.fill_color INK
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
                   col_widths: anchos(pdf, sec), aligns: sec[:aligns] || {})
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

    n = sec[:headers].size
    return { 0 => pdf.bounds.width } if n == 1

    fija    = [(pdf.bounds.width * 0.62 / (n - 1)), 46].min
    minimos = sec[:col_min] || {}
    cols    = (1...n).to_h { |i| [i, [fija, minimos[i].to_f].max] }
    { 0 => pdf.bounds.width - cols.values.sum }.merge(cols)
  end
end
