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
    ])

    # Sin corte por sede: un paciente es de la organización, no de una sede. Lo que había agrupaba por la
    # sede de su última dispensación —una dimensión que no existe en el modelo— y dejaba a los
    # que nunca dispensaron en una fila que parecía una sede llamada "sin dispensaciones".
    pendiente_interno(pdf)

    titulo_seccion(pdf, "Nómina de pacientes")
    detalle(pdf)
  end

  private

  # Anchos de las seis columnas numéricas; la de la sede se lleva lo que sobra.
  COLS_CONTEO = [50, 68, 48, 68, 58, 58].freeze

  # Los pacientes sin registro no entran en la nómina —este documento declara la población
  # REGISTRADA— pero tampoco se ocultan: se informa cuántos son, que es lo que la organización tiene
  # pendiente de resolver.
  def pendiente_interno(pdf)
    sin_registro = @data[:pacientes_sin_registro].to_i
    return if sin_registro.zero?

    pdf.move_down 4
    pdf.fill_color GRAY
    pdf.font(SANS) do
      pdf.text "La organización tiene además #{sin_registro} paciente#{'s' if sin_registro != 1} activo" \
               "#{'s' if sin_registro != 1} sin REPROCANN iniciado, que no integran esta nómina.",
               size: 8
    end
    pdf.fill_color INK
    pdf.move_down 6
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
                  "Se listan hasta 200 socios. Basado en el padrón vigente de la organización al momento de emisión.")
  end
end
