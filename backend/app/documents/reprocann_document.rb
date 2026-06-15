# Informe REPROCANN en PDF (piloto del molde BaseDocument).
# Recibe el mismo hash de datos que arma InformesController#reprocann,
# así el PDF y el JSON comparten una sola fuente de verdad.
class ReprocannDocument < BaseDocument
  ESTADO_LABEL = {
    "vigente"                 => "Vigente",
    "por_vencer"              => "Por vencer (hasta 30 días)",
    "vencido"                 => "Vencido",
    "vigente_sin_vencimiento" => "Sin vencimiento",
    "sin_reprocann"           => "Sin REPROCANN",
  }.freeze

  def initialize(club:, usuario:, data:)
    @data = data
    super(club: club, usuario: usuario,
          titulo: "Informe REPROCANN",
          subtitulo: "Emitido #{Date.current.strftime('%d/%m/%Y')}")
  end

  def cuerpo(pdf)
    resumen(pdf)
    pdf.move_down 18
    detalle(pdf)
  end

  private

  def resumen(pdf)
    titulo_seccion(pdf, "Resumen de situación")

    filas = [
      ["Total de socios",          @data[:total_pacientes]],
      ["Con REPROCANN vigente",    @data[:con_reprocann_vigente]],
      ["Vencen en 30 días",        @data[:vencen_30d]],
      ["Vencidos",                 @data[:vencidos]],
      ["Sin REPROCANN",            @data[:sin_reprocann]],
    ].map { |k, v| [k, v.to_s] }

    pdf.table(filas, width: pdf.bounds.width, column_widths: { 1 => 90 }) do |t|
      t.cells.borders        = [:bottom]
      t.cells.border_color   = LINEA
      t.cells.border_width   = 0.6
      t.cells.padding        = [6, 8]
      t.cells.size           = 9.5
      t.column(1).align      = :right
      t.column(1).font_style = :bold
      t.column(0).text_color = GRIS
    end
  end

  def detalle(pdf)
    titulo_seccion(pdf, "Detalle anonimizado de socios")
    lista = @data[:lista_anonimizada] || []

    if lista.empty?
      pdf.fill_color GRIS
      pdf.text "Sin socios registrados.", size: 9
      pdf.fill_color TINTA
      return
    end

    encabezados = ["Iniciales", "DNI (últ. 4)", "Estado", "Vencimiento"]
    filas = lista.map do |p|
      venc = p[:reprocann_vencimiento].present? ? Date.parse(p[:reprocann_vencimiento].to_s).strftime("%d/%m/%Y") : "—"
      [
        p[:iniciales].to_s,
        p[:dni_ultimos_4].present? ? "**** #{p[:dni_ultimos_4]}" : "—",
        ESTADO_LABEL[p[:reprocann_estado].to_s] || p[:reprocann_estado].to_s,
        venc,
      ]
    end

    pdf.table([encabezados] + filas, width: pdf.bounds.width, header: true) do |t|
      t.cells.padding      = [5, 8]
      t.cells.size         = 8.5
      t.cells.borders      = [:bottom]
      t.cells.border_color = LINEA
      t.cells.border_width = 0.5
      t.row(0).font_style  = :bold
      t.row(0).background_color = VERDE
      t.row(0).text_color  = "FFFFFF"
      t.row(0).borders     = []
      t.column(1).align    = :center
      t.column(3).align    = :center
    end

    pdf.move_down 10
    pdf.fill_color GRIS_CLARO
    pdf.font(FUENTE) { pdf.text "Datos anonimizados conforme a la protección de datos personales. Se muestran hasta 200 socios.", size: 7 }
    pdf.fill_color TINTA
  end
end
