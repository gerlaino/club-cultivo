# Trazabilidad de un stock: de qué lote y de qué plantas salió, y a quién se entregó.
#
# Es lo primero que pide un auditor cuando señala un producto — "¿de dónde salió esto?" — y
# se bajaba como una captura de pantalla. El documento reconstruye la cadena completa en el
# orden en que se recorre: producto → genética → lote → plantas → entregas.
#
# Los pacientes van con nombre, apellido y DNI COMPLETO. Antes eran sólo iniciales, con el
# argumento de no exponer datos: no protegía nada —quien abre este informe ya puede ver la ficha
# completa de cada paciente— y dejaba una tabla ilegible, donde dos "G.L." son indistinguibles y
# no se puede cruzar con ningún otro registro.
#
# El documento completo va en lo que se DESCARGA, no en la pantalla: el PDF se presenta ante un
# organismo o un auditor, y con el documento tapado no acredita a nadie. En pantalla siguen los
# últimos cuatro, que alcanzan para desambiguar homónimos sin dejar el padrón a la vista de
# cualquiera que pase por atrás.
class TrazabilidadDocument < BaseDocument
  def initialize(club:, usuario:, datos:)
    @d = datos.deep_symbolize_keys
    st = @d[:stock] || {}
    super(club: club, usuario: usuario,
          titulo: "Trazabilidad — #{st[:numero_lote_producto].presence || "Stock ##{st[:id]}"}",
          tipo_doc: "Trazabilidad", tipo_code: "TRZ")
  end

  def cuerpo(pdf)
    t = @d[:totales] || {}
    stat_strip(pdf, [
      { label: "Producido",    valor: "#{@d.dig(:stock, :cantidad_inicial_g)} g" },
      { label: "Disponible",   valor: "#{t[:cantidad_disponible_g]} g", tono: :ok },
      { label: "Dispensado",   valor: "#{t[:gramos_dispensados]} g" },
      { label: "Plantas origen", valor: t[:plantas_origen] },
      { label: "Entregas",     valor: t[:dispensaciones_count] },
    ])

    producto(pdf)
    origen(pdf)
    plantas(pdf)
    entregas(pdf)
  end

  private

  def producto(pdf)
    st = @d[:stock] || {}
    g  = st[:genetica] || {}
    titulo_seccion(pdf, "El producto")
    filas = [
      ["Identificación", st[:numero_lote_producto].presence || "—"],
      ["Forma",          st[:forma_producto].to_s.tr("_", " ").capitalize],
      ["Elaborado el",   fecha(st[:fecha_elaboracion])],
      ["Genética",       g[:nombre].presence || "—"],
      ["Registro INASE", g[:numero_registro_inase].presence || "Sin registrar"],
      ["THC / CBD",      [g[:thc], g[:cbd]].any?(&:present?) ? "#{g[:thc] || '—'}% / #{g[:cbd] || '—'}%" : "—"],
    ]
    tabla_datos(pdf, filas)
  end

  def origen(pdf)
    lote = @d[:lote]
    pes  = @d[:pesada]
    titulo_seccion(pdf, "De dónde salió")
    if lote.blank?
      vacio(pdf, "Este stock no proviene de un lote propio (compra externa o carga manual).")
      return
    end

    filas = [
      ["Lote",   lote[:codigo].to_s],
      ["Estado", lote[:estado].to_s.tr("_", " ").capitalize],
    ]
    if pes.present?
      filas << ["Pesaje",        "#{pes[:peso_total_g]} g el #{fecha(pes[:registrado_at])}"]
      filas << ["Plantas pesadas", pes[:plantas_count].to_s]
    end
    tabla_datos(pdf, filas)
  end

  def plantas(pdf)
    ps = Array(@d[:plantas])
    titulo_seccion(pdf, "Plantas de origen")
    if ps.empty?
      vacio(pdf, "El pesaje no dejó registro planta por planta: el origen se acredita a nivel de lote.")
      return
    end

    # Un auditor lee esta tabla como "de estas plantas salió este frasco". Cuando no hay pesaje
    # por planta eso NO es lo que dice el dato, y el documento tiene que decirlo antes de la
    # tabla, no dejar que se lea de más.
    if @d[:atribucion] == 'lote'
      nota(pdf, "Sin pesaje planta por planta: son las plantas vivas del lote de origen, no una " \
                "medición individual. El peso figura a nivel de lote.")
    end

    styled_table(pdf, ["Planta (QR)", "Origen", "Peso"],
                 ps.map { |p| [p[:codigo_qr].to_s, p[:origen].to_s.capitalize,
                               "#{p[:peso_g] || '—'} g#{p[:promedio] ? ' (prom.)' : ''}"] },
                 col_widths: { 0 => pdf.bounds.width - 220, 1 => 110, 2 => 110 },
                 aligns: { 2 => :right })
    pdf.move_down 8

    descartadas(pdf)
  end

  # Las plantas que no llegaron a producir, con el motivo. Sin esto, el que compara la cantidad
  # de plantas del lote contra esta tabla ve un hueco sin explicación — y un hueco sin explicar,
  # en un informe de trazabilidad, es exactamente lo que un auditor pregunta.
  def descartadas(pdf)
    ds = Array(@d[:plantas_descartadas])
    return if ds.empty?

    titulo_seccion(pdf, "Plantas descartadas del lote")
    nota(pdf, "No produjeron: no son origen de este producto. Se listan para que la cuenta de " \
              "plantas del lote cierre.")
    styled_table(pdf, ["Planta (QR)", "Motivo"],
                 ds.map { |p| [p[:codigo_qr].to_s, p[:motivo_descarte].to_s.tr("_", " ").capitalize.presence || "—"] },
                 col_widths: { 0 => pdf.bounds.width - 220, 1 => 220 })
    pdf.move_down 8
  end

  def nota(pdf, texto)
    pdf.fill_color GRAY
    pdf.font(SANS) { pdf.text texto, size: 7.5 }
    pdf.fill_color INK
    pdf.move_down 4
  end

  def entregas(pdf)
    ds = Array(@d[:dispensaciones])
    titulo_seccion(pdf, "A quién se entregó")
    if ds.empty?
      vacio(pdf, "Todavía no se dispensó nada de este producto.")
      return
    end

    styled_table(pdf, ["Fecha", "Paciente", "DNI", "Cantidad"],
                 ds.map { |d| [fecha(d[:fecha]), (d[:paciente].presence || d[:paciente_iniciales]).to_s,
                               (d[:paciente_dni].presence || "***#{d[:paciente_dni_last3]}"),
                               "#{d[:cantidad_g]} g"] },
                 col_widths: { 0 => 90, 1 => pdf.bounds.width - 310, 2 => 110, 3 => 110 },
                 aligns: { 3 => :right })
    pdf.move_down 6
    pdf.fill_color GRAY
    pdf.font(SANS) do
      pdf.text "El documento se muestra parcial (últimos cuatro dígitos). El informe contiene " \
               "datos personales de pacientes: tratar como información sensible.", size: 7.5
    end
    pdf.fill_color INK
  end

  def tabla_datos(pdf, filas)
    styled_table(pdf, ["Dato", "Detalle"], filas.map { |r| r.map(&:to_s) },
                 col_widths: { 0 => 140, 1 => pdf.bounds.width - 140 })
    pdf.move_down 8
  end

  def vacio(pdf, texto)
    pdf.fill_color GRAY
    pdf.font(SANS) { pdf.text texto, size: 9 }
    pdf.fill_color INK
    pdf.move_down 8
  end

  def fecha(f)
    return "—" if f.blank?
    (f.is_a?(String) ? Time.zone.parse(f) : f).strftime("%d/%m/%Y")
  rescue ArgumentError, TypeError
    f.to_s
  end
end
