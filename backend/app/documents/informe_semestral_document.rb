# La declaración jurada semestral en PDF: EL documento que se presenta ante la autoridad.
#
# Identifica al establecimiento, lista la población registrada en REPROCANN al cierre del
# semestre con su vigencia ESE día, lo cosechado en el semestre por variedad acreditada ante el
# INASE (con las genéticas propias que acredita y el origen del material) y las entregas a esa
# población, por unidad. Todo sale del mismo hash que la pantalla (`Informes::Semestral`).
#
# La nómina va con nombre, apellido y documento completo: la autoridad necesita identificar a
# cada paciente. Por eso tampoco lo puede pedir cualquiera (ver el guard del controller).
# Los aportes en pesos NO van: es una declaración sanitaria, y la plata de la organización no es
# asunto del Ministerio de Salud (decisión de Germán, sep-2026).
class InformeSemestralDocument < BaseDocument
  ESTADO = { 'vigente' => 'Vigente', 'por_vencer' => 'Vigente', 'vencido' => 'Vencido',
             'pendiente' => 'Pendiente de aprobación', 'sin_reprocann' => 'Sin número' }.freeze
  NIVEL  = { 'vigente' => :ok, 'por_vencer' => :ok, 'vencido' => :crit, 'pendiente' => :warn, 'sin_reprocann' => :warn }.freeze

  def initialize(club:, usuario:, datos:, salvedad_inase: nil)
    @d = datos.deep_symbolize_keys
    per = @d[:periodo] || {}
    super(club: club, usuario: usuario,
          titulo: "Declaración jurada semestral REPROCANN — #{per[:semestre]}° semestre #{per[:anio]}",
          tipo_doc: "Declaración semestral", tipo_code: "SEM", salvedad_inase: salvedad_inase)
  end

  def cuerpo(pdf)
    periodo(pdf)
    establecimiento(pdf)
    pacientes(pdf)
    cultivo(pdf)
    entregas(pdf)
    firma(pdf)
  end

  private

  def periodo(pdf)
    p = @d[:periodo] || {}
    pdf.fill_color GRAY
    pdf.font(SANS) do
      pdf.text "Período declarado: #{fecha(p[:desde])} — #{fecha(p[:hasta])}", size: 9
      pdf.text "Población y cultivo al #{fecha(p[:al])}#{p[:cerrado] ? '' : ' (semestre en curso)'}", size: 9
    end
    pdf.fill_color INK
    pdf.move_down 10
  end

  def establecimiento(pdf)
    c = @d[:club] || {}
    titulo_seccion(pdf, "Establecimiento")

    filas = [
      ["Denominación",     c[:nombre_legal].presence || c[:nombre]],
      ["Domicilio",        [c[:direccion], c[:ciudad], c[:provincia], c[:pais]].compact_blank.join(", ")],
      ["Contacto",         [c[:email], c[:telefono]].compact_blank.join("   ·   ")],
      ["Resol. REPROCANN", c[:numero_resolucion_reprocann].present? ? "N.º #{c[:numero_resolucion_reprocann]}" : nil],
    ].reject { |(_, v)| v.blank? }

    styled_table(pdf, ["Dato", "Detalle"], filas.map { |r| r.map(&:to_s) },
                 col_widths: { 0 => 130, 1 => pdf.bounds.width - 130 })
    pdf.move_down 8

    sedes = Array(c[:sedes_reprocann])
    return if sedes.empty?

    titulo_seccion(pdf, "Sedes declaradas ante REPROCANN")
    styled_table(pdf, ["Sede", "Tipo", "Domicilio"],
                 sedes.map { |s| [s[:nombre].to_s, s[:tipo].to_s, s[:direccion].to_s] },
                 col_widths: { 0 => 150, 1 => 100, 2 => pdf.bounds.width - 250 })
    pdf.move_down 8
  end

  def pacientes(pdf)
    p = @d[:pacientes] || {}
    titulo_seccion(pdf, "Pacientes registrados en REPROCANN")
    stat_strip(pdf, [
      { label: "Registrados",       valor: p[:registrados] },
      { label: "Vigentes al cierre", valor: p[:vigentes], tono: :ok },
      { label: "Vencidos al cierre", valor: p[:vencidos], tono: (p[:vencidos].to_i.positive? ? :crit : nil) },
      { label: "Pendientes de aprobación", valor: p[:en_tramite] },
      { label: "Sin registro",      valor: p[:sin_registro] },
    ])
    nota(pdf, "«Sin registro» son pacientes de la organización que no iniciaron el trámite: se informa el " \
              "número y no integran la nómina.")

    nomina = Array(p[:nomina])
    titulo_seccion(pdf, "Nómina")
    if nomina.empty?
      nota(pdf, "La organización no tenía pacientes registrados al cierre del período.")
      return
    end

    rows = nomina.map do |s|
      [s[:nombre_completo].to_s, s[:dni].to_s, fecha(s[:fecha_nacimiento]),
       s[:reprocann_numero].presence || "—", fecha(s[:reprocann_vencimiento]),
       ESTADO[s[:reprocann_estado]] || s[:reprocann_estado].to_s]
    end
    niveles = nomina.map { |s| NIVEL[s[:reprocann_estado]] || :warn }

    styled_table(pdf, ["Paciente", "DNI", "Nacimiento", "N° REPROCANN", "Vence", "Estado al cierre"], rows,
                 col_widths: { 0 => pdf.bounds.width - 360, 1 => 70, 2 => 70, 3 => 90, 4 => 60, 5 => 70 },
                 status_col: 5, status_levels: niveles)
    pdf.move_down 8
  end

  def cultivo(pdf)
    c  = @d[:cultivo] || {}
    co = c[:cosechados] || {}
    ep = c[:en_pie] || {}
    titulo_seccion(pdf, "Cultivo del período")
    stat_strip(pdf, [
      { label: "Lotes cosechados",   valor: co[:lotes] },
      { label: "Plantas cosechadas", valor: co[:plantas] },
      { label: "Flor seca",          valor: gramos(co[:gramos]), tono: :ok },
      { label: "Lotes en pie al cierre",   valor: ep[:lotes] },
      { label: "Plantas en pie al cierre", valor: ep[:plantas] },
    ])

    variedades = Array(c[:variedades])
    if variedades.empty?
      nota(pdf, "No se cosechó ningún lote en el período.")
      return
    end

    rows = variedades.map do |v|
      nombre = v[:nombre].to_s
      nombre += " (acredita: #{v[:acredita].join(', ')})" if Array(v[:acredita]).any?
      nombre += " — SIN VINCULACIÓN INASE" unless v[:vinculada]
      [nombre, v[:criador].presence || "—", v[:lotes].to_s, v[:plantas].to_s,
       "#{v.dig(:origen, :semilla).to_i} / #{v.dig(:origen, :esqueje).to_i}", gramos(v[:gramos])]
    end
    styled_table(pdf, ["Variedad (Catálogo Nacional)", "Obtentor", "Lotes", "Plantas", "Semilla / esqueje", "Flor seca"], rows,
                 col_widths: { 0 => pdf.bounds.width - 330, 1 => 100, 2 => 45, 3 => 50, 4 => 75, 5 => 60 },
                 aligns: { 2 => :right, 3 => :right, 4 => :right, 5 => :right })
    nota(pdf, "Una fila por variedad acreditable; «acredita» lista con qué nombre la cultiva la organización. " \
              "Semilla / esqueje: origen del material de propagación de cada planta.")
  end

  def entregas(pdf)
    e = @d[:entregas] || {}
    titulo_seccion(pdf, "Entregas del período a la población registrada")
    items = [
      { label: "Entregas",  valor: e[:entregas] },
      { label: "Pacientes", valor: e[:pacientes] },
    ]
    Array(e[:por_unidad]).each { |u| items << { label: etiqueta_unidad(u[:unidad]), valor: cantidad(u[:cantidad], u[:unidad]), tono: :ok } }
    stat_strip(pdf, items.first(5))
    return unless e[:sin_reprocann_vigente].to_i.positive?

    nota(pdf, "#{e[:sin_reprocann_vigente]} entregas se realizaron a pacientes sin REPROCANN vigente el día de la entrega.")
  end

  def firma(pdf)
    pdf.move_down 40
    y = pdf.cursor
    ancho = 220
    x = pdf.bounds.width - ancho
    pdf.stroke_color LINE
    pdf.line_width 0.5
    pdf.stroke_horizontal_line x, x + ancho, at: y
    pdf.fill_color GRAY
    pdf.font(SANS) { pdf.text_box "Firma y aclaración del responsable legal", at: [x, y - 4], width: ancho, size: 8, align: :center }
    pdf.fill_color INK
  end

  def nota(pdf, texto)
    pdf.fill_color GRAY
    pdf.font(SANS) { pdf.text texto, size: 8 }
    pdf.fill_color INK
    pdf.move_down 8
  end

  def fecha(f)
    return "—" if f.blank?
    (f.is_a?(String) ? Date.parse(f) : f).strftime("%d/%m/%Y")
  rescue ArgumentError, TypeError
    f.to_s
  end

  def gramos(g) = "#{ActiveSupport::NumberHelper.number_to_delimited(g.to_f.round(1), delimiter: '.', separator: ',')} g"

  def cantidad(n, unidad)
    valor = ActiveSupport::NumberHelper.number_to_delimited(n.to_f.round(2), delimiter: '.', separator: ',')
    unidad == 'un' ? valor : "#{valor} #{unidad}"
  end

  def etiqueta_unidad(u)
    { 'g' => 'Gramos', 'un' => 'Unidades', 'ml' => 'Mililitros' }[u.to_s] || u.to_s
  end
end
