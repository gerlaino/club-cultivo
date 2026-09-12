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
# últimos tres, que alcanzan para desambiguar homónimos sin dejar el padrón a la vista de
# cualquiera que pase por atrás (decisión de Germán, sep-2026).
#
# LA CUENTA VA PRIMERO: es la única parte que un auditor comprueba con lápiz. Una oración que se
# lee en voz alta, las cuatro cifras, y cada salida con su nombre — un traslado o un derivado no
# son merma, son el mismo producto en otra fila.
class TrazabilidadDocument < BaseDocument
  def initialize(club:, usuario:, datos:, salvedad_inase: nil)
    @d = datos.deep_symbolize_keys
    st = @d[:stock] || {}
    super(club: club, usuario: usuario,
          titulo: "Trazabilidad — #{st[:numero_lote_producto].presence || "Stock ##{st[:id]}"}",
          tipo_doc: "Trazabilidad", tipo_code: "TRZ", salvedad_inase: salvedad_inase)
  end

  def cuerpo(pdf)
    t = @d[:totales] || {}
    u = @d.dig(:stock, :unidad).presence || "g"
    stat_strip(pdf, [
      { label: "Entró",            valor: "#{t[:gramos_producidos]} #{u}" },
      { label: "A pacientes",      valor: "#{t[:gramos_dispensados]} #{u}" },
      { label: "Salió por otro lado", valor: "#{t[:otras_salidas_g]} #{u}" },
      { label: "Queda",            valor: "#{t[:cantidad_disponible_g]} #{u}", tono: :ok },
      { label: "Sin explicar",     valor: "#{t[:sin_explicar_g]} #{u}", tono: t[:sin_explicar_g].to_f.zero? ? :ok : :warn },
    ])
    frase(pdf)
    salidas(pdf)

    producto(pdf)
    origen(pdf)
    cronologia(pdf)
    plantas(pdf)
    entregas(pdf)
  end

  private

  def frase(pdf)
    return if @d[:frase].blank?

    pdf.move_down 4
    pdf.font(SANS) { pdf.text @d[:frase].to_s, size: 9.5 }
    pdf.move_down 8
  end

  # Cada salida con su tipo y su destino. Lo que sigue existiendo en otra fila lleva el número
  # de esa fila: desde acá se sigue la cadena.
  def salidas(pdf)
    ss = Array(@d[:salidas])
    return if ss.empty?

    u = @d.dig(:stock, :unidad).presence || "g"
    titulo_seccion(pdf, "Salió por otro lado")
    styled_table(pdf, ["Fecha", "Qué pasó", "Destino", "Cantidad"],
                 ss.map { |m|
                   [fecha(m[:fecha]), "#{TIPOS[m[:tipo]] || m[:tipo]}#{m[:detalle].present? ? " · #{m[:detalle]}" : ''}",
                    m[:destino] ? [m[:destino][:numero], m[:destino][:sede]].compact.join(" · ") : "—",
                    "#{m[:gramos]} #{u}"]
                 },
                 col_widths: { 0 => 70, 1 => pdf.bounds.width - 310, 2 => 150, 3 => 90 },
                 aligns: { 3 => :right })
    pdf.move_down 8
  end

  TIPOS = {
    "transferencia"  => "Traslado a otra sede",
    "produccion"     => "Elaboración de un derivado",
    "consumo_evento" => "Consumo en evento",
    "salida"         => "Salida",
    "ajuste"         => "Ajuste de conteo",
    "merma"          => "Merma",
  }.freeze

  ESTADOS = {
    "enraizado" => "Enraizado", "vegetativo" => "Vegetativo", "floracion" => "Floración",
    "cosecha" => "Cosecha", "en_manicura" => "En manicura", "curado" => "Curado", "finalizado" => "Finalizado",
  }.freeze

  # Las fechas del ciclo: cada cambio de estado con los días que llevó el anterior, los descartes
  # y los pesajes. Es lo que el auditor cruza con el cuaderno de campo.
  def cronologia(pdf)
    cs = Array(@d[:cronologia])
    return if cs.empty?

    titulo_seccion(pdf, "Cronología del lote")
    styled_table(pdf, ["Fecha", "Qué pasó", "Detalle"],
                 cs.map { |c| [fecha(c[:fecha]), c[:tipo] == "estado" ? (ESTADOS[c[:estado]] || c[:titulo].to_s) : c[:titulo].to_s, c[:detalle].to_s.presence || "—"] },
                 col_widths: { 0 => 70, 1 => 170, 2 => pdf.bounds.width - 240 })
    pdf.move_down 8
  end

  def producto(pdf)
    st = @d[:stock] || {}
    g  = st[:genetica] || {}
    titulo_seccion(pdf, "El producto")
    filas = [
      ["Identificación", st[:numero_lote_producto].presence || "—"],
      ["Forma",          st[:forma_producto].to_s.tr("_", " ").capitalize],
      ["Elaborado el",   fecha(st[:fecha_elaboracion])],
      ["Dónde está",     [st[:sede].presence, ("#{@d.dig(:totales, :en_mesa_g)} sobre la mesa" if @d.dig(:totales, :en_mesa_g).to_f.positive?)].compact.join(" · ").presence || "—"],
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
    st = @d[:stock] || {}
    if lote.blank?
      # Un producto comprado afuera no tiene lote: tiene proveedor. Eso es su origen.
      if st[:proveedor].present?
        tabla_datos(pdf, [["Proveedor", st[:proveedor].to_s], ["Origen", "Compra externa"]])
      else
        vacio(pdf, "Este stock no proviene de un lote propio (compra externa o carga manual).")
      end
      return
    end

    filas = []
    # Un derivado hereda la cadena de la flor de la que salió, y dice de qué frasco.
    if st[:producido_desde].present?
      filas << ["Elaborado de", "#{st[:producido_desde][:gramos]} g de #{st[:producido_desde][:numero]}"]
    end
    filas += [
      ["Lote",   lote[:codigo].to_s],
      ["Estado", ESTADOS[lote[:estado].to_s] || lote[:estado].to_s.tr("_", " ").capitalize],
    ]
    sig = Array(@d[:siguio_en])
    if sig.any?
      filas << ["Siguió en", sig.map { |x| "#{x[:numero]} (#{x[:tipo] == 'derivado' ? 'derivado' : 'traslado'}, #{x[:gramos]} g#{x[:sede] ? ", #{x[:sede]}" : ''})" }.join("; ")]
    end
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

    u = @d.dig(:stock, :unidad).presence || "g"
    styled_table(pdf, ["Fecha", "Paciente", "DNI", "Cómo", "Cantidad"],
                 ds.map { |d| [fecha(d[:fecha]), (d[:paciente].presence || d[:paciente_iniciales]).to_s,
                               (d[:paciente_dni].presence || "···#{d[:paciente_dni_last3]}"),
                               [d[:canal], (d[:junto_con].present? ? "con #{Array(d[:junto_con]).join(', ')}" : nil)].compact.join(" · "),
                               "#{d[:cantidad_g]} #{u}"] },
                 col_widths: { 0 => 70, 1 => pdf.bounds.width - 390, 2 => 90, 3 => 150, 4 => 80 },
                 aligns: { 4 => :right })
    pdf.move_down 6
    pdf.fill_color GRAY
    pdf.font(SANS) do
      pdf.text "El informe contiene datos personales de pacientes: tratar como información sensible.", size: 7.5
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
