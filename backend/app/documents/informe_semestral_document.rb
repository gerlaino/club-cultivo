# Informe semestral REPROCANN en PDF.
#
# Es el documento regulatorio más completo del club: identifica al establecimiento, lista la
# nómina de pacientes con su certificado y resume producción y dispensaciones del semestre.
# Se generaba con html2canvas —una foto de la pantalla— y por eso salía sin texto
# seleccionable, cortado y con la calidad atada al zoom del navegador.
#
# La nómina va con nombre y apellido: este documento se presenta ante la autoridad, que
# necesita identificar a cada paciente. Por eso tampoco lo puede pedir cualquiera (ver el
# guard de InformeSemestralController). Desde agosto 2026 el resto de los informes también
# muestra el nombre completo: las iniciales no protegían nada frente a quien ya tiene acceso
# a las fichas, y volvían las tablas ilegibles.
class InformeSemestralDocument < BaseDocument
  def initialize(club:, usuario:, datos:)
    @d = datos.deep_symbolize_keys
    per = @d[:periodo] || {}
    super(club: club, usuario: usuario,
          titulo: "Informe semestral REPROCANN — #{per[:semestre]}° semestre #{per[:anio]}",
          tipo_doc: "Informe semestral", tipo_code: "SEM")
  end

  def cuerpo(pdf)
    periodo(pdf)
    establecimiento(pdf)
    pacientes(pdf)
    produccion(pdf)
    dispensaciones(pdf)
    geneticas(pdf)
  end

  private

  def periodo(pdf)
    p = @d[:periodo] || {}
    pdf.fill_color GRAY
    pdf.font(SANS) { pdf.text "Período informado: #{fecha(p[:desde])} — #{fecha(p[:hasta])}", size: 9 }
    pdf.fill_color INK
    pdf.move_down 10
  end

  def establecimiento(pdf)
    c = @d[:club] || {}
    titulo_seccion(pdf, "Establecimiento")

    filas = [
      ["Denominación",   c[:nombre_legal].presence || c[:nombre]],
      ["Domicilio",      [c[:direccion], c[:ciudad], c[:provincia], c[:pais]].compact_blank.join(", ")],
      ["Contacto",       [c[:email], c[:telefono]].compact_blank.join("   ·   ")],
    ].reject { |(_, v)| v.blank? }

    styled_table(pdf, ["Dato", "Detalle"], filas.map { |r| r.map(&:to_s) },
                 col_widths: { 0 => 130, 1 => pdf.bounds.width - 130 })
    pdf.move_down 8

    sedes = Array(c[:sedes_reprocann])
    if sedes.any?
      titulo_seccion(pdf, "Sedes declaradas ante REPROCANN")
      styled_table(pdf, ["Sede", "Tipo", "Domicilio"],
                   sedes.map { |s| [s[:nombre].to_s, s[:tipo].to_s, s[:direccion].to_s] },
                   col_widths: { 0 => 150, 1 => 100, 2 => pdf.bounds.width - 250 })
      pdf.move_down 8
    end
  end

  def pacientes(pdf)
    p = @d[:pacientes] || {}
    titulo_seccion(pdf, "Pacientes")
    stat_strip(pdf, [
      { label: "Total",          valor: p[:total] },
      { label: "Con REPROCANN",  valor: p[:con_reprocann], tono: :ok },
      { label: "Sin REPROCANN",  valor: p[:sin_reprocann] },
      { label: "Vencidos",       valor: p[:vencidos],   tono: :crit },
      { label: "Por vencer",     valor: p[:por_vencer], tono: :warn },
    ])

    nomina = Array(p[:nomina])
    titulo_seccion(pdf, "Nómina")
    if nomina.empty?
      vacio(pdf, "El club no tiene pacientes registrados en el período.")
      return
    end

    rows = nomina.map do |s|
      [s[:nombre_completo].to_s, s[:dni].to_s, fecha(s[:fecha_nacimiento]),
       s[:reprocann_numero].to_s, fecha(s[:reprocann_vencimiento]),
       s[:reprocann_vigente] ? "Vigente" : "No vigente"]
    end
    niveles = nomina.map { |s| s[:reprocann_vigente] ? :ok : :crit }

    styled_table(pdf, ["Paciente", "DNI", "Nacimiento", "N° REPROCANN", "Vence", "Estado"], rows,
                 col_widths: { 0 => pdf.bounds.width - 350, 1 => 70, 2 => 70, 3 => 90, 4 => 60, 5 => 60 },
                 status_col: 5, status_levels: niveles)
    pdf.move_down 8
  end

  def produccion(pdf)
    pr = @d[:produccion] || {}
    titulo_seccion(pdf, "Producción")
    stat_strip(pdf, [
      { label: "Plantas",      valor: pr[:plantas_totales] },
      { label: "En vegetativo", valor: pr[:plantas_en_vegetativo] },
      { label: "En floración",  valor: pr[:plantas_en_floracion] },
    ])
  end

  def dispensaciones(pdf)
    di = @d[:dispensaciones] || {}
    titulo_seccion(pdf, "Dispensaciones del período")
    stat_strip(pdf, [
      { label: "Entregas",  valor: di[:total] },
      { label: "Gramos",    valor: di[:total_gramos], tono: :ok },
      { label: "Aportes",   valor: "$#{fmt_miles(di[:aporte_total_ars])}" },
    ])

    por_tipo = Array(di[:por_tipo_producto])
    return if por_tipo.empty?

    styled_table(pdf, ["Tipo de producto", "Gramos"],
                 por_tipo.map { |t| [t[:tipo].to_s.tr('_', ' ').capitalize, t[:gramos].to_s] },
                 col_widths: { 0 => pdf.bounds.width - 120, 1 => 120 },
                 aligns: { 1 => :right })
    pdf.move_down 8
  end

  def geneticas(pdf)
    gs = Array(@d[:resumen_geneticas])
    return if gs.empty?

    titulo_seccion(pdf, "Genéticas cultivadas")
    styled_table(pdf, ["Genética", "Lotes", "Gramos producidos"],
                 gs.map { |g| [g[:nombre].to_s, g[:lotes_count].to_s, g[:gramos_producidos].to_s] },
                 col_widths: { 0 => pdf.bounds.width - 220, 1 => 100, 2 => 120 },
                 aligns: { 1 => :right, 2 => :right })
  end

  def vacio(pdf, texto)
    pdf.fill_color GRAY
    pdf.font(SANS) { pdf.text texto, size: 9 }
    pdf.fill_color INK
    pdf.move_down 8
  end

  def fecha(f)
    return "—" if f.blank?
    (f.is_a?(String) ? Date.parse(f) : f).strftime("%d/%m/%Y")
  rescue ArgumentError, TypeError
    f.to_s
  end

  def fmt_miles(n)
    n.to_f.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
  end
end
