# Informe REPROCANN en PDF (piloto del sistema de diseño premium).
class ReprocannDocument < BaseDocument
  ESTADO_LABEL = {
    "vigente"                 => "Vigente",
    "por_vencer"              => "Por vencer",
    "vencido"                 => "Vencido",
    "vigente_sin_vencimiento" => "Sin vencimiento",
    "sin_reprocann"           => "Sin REPROCANN",
  }.freeze

  ESTADO_NIVEL = {
    "vigente"                 => :ok,
    "por_vencer"              => :warn,
    "vencido"                 => :crit,
    "vigente_sin_vencimiento" => :ok,
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
      { label: "Socios totales",  valor: @data[:total_pacientes] },
      { label: "Vigentes",        valor: @data[:con_reprocann_vigente], tono: :ok },
      { label: "Vencen ≤30 días", valor: @data[:vencen_30d],            tono: :warn },
      { label: "Vencidos",        valor: @data[:vencidos],              tono: :crit },
      { label: "Sin REPROCANN",   valor: @data[:sin_reprocann] },
    ])

    titulo_seccion(pdf, "Detalle anonimizado de socios")
    detalle(pdf)
  end

  private

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
        p[:iniciales].to_s,
        p[:dni_ultimos_4].present? ? "**** #{p[:dni_ultimos_4]}" : "—",
        ESTADO_LABEL[estado] || estado,
        venc,
      ]
      levels << ESTADO_NIVEL[estado]
    end

    styled_table(pdf,
      ["Iniciales", "DNI (últ. 4)", "Estado", "Vencimiento"],
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
