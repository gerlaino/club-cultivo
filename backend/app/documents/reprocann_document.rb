# Informe REPROCANN en PDF (piloto del sistema de diseño premium).
class ReprocannDocument < BaseDocument
  ESTADO_LABEL = {
    "vigente"                 => "Vigente",
    "por_vencer"              => "Por vencer",
    "vencido"                 => "Vencido",
    "pendiente"               => "Pendiente de aprobación",
    "sin_reprocann"           => "Sin REPROCANN",
  }.freeze

  ESTADO_NIVEL = {
    "vigente"                 => :ok,
    "por_vencer"              => :warn,
    "vencido"                 => :crit,
    "pendiente"               => :warn,
    "sin_reprocann"           => nil,
  }.freeze

  def initialize(club:, usuario:, data:)
    @data = data
    super(club: club, usuario: usuario,
          titulo: "Informe REPROCANN", tipo_doc: "Informe REPROCANN", tipo_code: "RPC")
  end

  def cuerpo(pdf)
    titulo_seccion(pdf, "Resumen de situación")
    stat_strip(pdf, [
      { label: "Pacientes activos", valor: @data[:total_pacientes] },
      { label: "Vigentes",        valor: @data[:con_reprocann_vigente], tono: :ok },
      { label: "Vencen ≤30 días", valor: @data[:vencen_30d],            tono: :warn },
      { label: "Vencidos",        valor: @data[:vencidos],              tono: :crit },
      { label: "Trámite pendiente", valor: @data[:pendientes],          tono: :warn },
      { label: "Sin REPROCANN",   valor: @data[:sin_reprocann] },
    ])

    por_sede(pdf)

    titulo_seccion(pdf, "Detalle anonimizado de socios")
    detalle(pdf)
  end

  private

  # Anchos de las seis columnas numéricas; la de la sede se lleva lo que sobra.
  COLS_CONTEO = [50, 68, 48, 68, 58, 58].freeze

  # El paciente no tiene sede propia: se atiende donde dispensa.
  def por_sede(pdf)
    filas = @data[:por_sede] || []
    return if filas.empty?

    titulo_seccion(pdf, "Pacientes por sede de atención")
    # Encabezados abreviados: con los nombres completos las siete columnas piden 534pt y el
    # ancho útil del A4 es 487. La referencia de qué significa cada una va debajo.
    styled_table(pdf,
      ["Sede", "Pac.", "Vigentes", "≤30d", "Vencidos", "Trámite", "S/REPRO"],
      filas.map { |r|
        [r[:sede].to_s, r[:total].to_s, r[:vigentes].to_s, r[:por_vencer].to_s,
         r[:vencidos].to_s, r[:pendientes].to_s, r[:sin_reprocann].to_s]
      },
      # `styled_table` necesita anchos explícitos (Prawn no acepta nil) y que sumen EXACTAMENTE
      # el ancho del marco. Las columnas de conteo son fijas y la de la sede absorbe el resto,
      # así no hay que reajustar números a mano si cambian los márgenes.
      col_widths: { 0 => pdf.bounds.width - COLS_CONTEO.sum,
                    **COLS_CONTEO.each_with_index.to_h { |w, i| [i + 1, w] } },
      aligns:     { 1 => :right, 2 => :right, 3 => :right, 4 => :right, 5 => :right, 6 => :right })

    pdf.move_down 4
    pdf.fill_color GRAY
    pdf.font(SANS) do
      pdf.text "Pac. = pacientes activos · ≤30d = vencen dentro de 30 días · " \
               "Trámite = pendiente de aprobación · S/REPRO = sin REPROCANN", size: 7
    end
    pdf.fill_color INK
  end

  def detalle(pdf)
    lista = @data[:lista_anonimizada] || []
    if lista.empty?
      pdf.fill_color GRAY
      pdf.font(SANS) { pdf.text "Sin socios registrados.", size: 9 }
      pdf.fill_color INK
      return
    end

    rows   = []
    levels = []
    lista.each do |p|
      venc = p[:reprocann_vencimiento].present? ? Date.parse(p[:reprocann_vencimiento].to_s).strftime("%d/%m/%Y") : "—"
      estado = p[:reprocann_estado].to_s
      rows << [
        p[:nombre_completo].presence || p[:iniciales].to_s,
        p[:dni_ultimos_3].present? ? "***#{p[:dni_ultimos_3]}" : "—",
        ESTADO_LABEL[estado] || estado,
        venc,
      ]
      levels << ESTADO_NIVEL[estado]
    end

    styled_table(pdf,
      ["Paciente", "DNI (últ. 3)", "Estado", "Vencimiento"],
      rows,
      aligns:        { 1 => :center, 3 => :center },
      mono:          [1, 3],
      status_col:    2,
      status_levels: levels,
      col_widths:    { 0 => 90, 1 => 110, 3 => 110 },
    )

    nota_pie(pdf, "DATOS ANONIMIZADOS conforme a la Ley 25.326 de Protección de Datos Personales. " \
                  "Se listan hasta 200 socios. Basado en el padrón vigente del club al momento de emisión.")
  end
end
