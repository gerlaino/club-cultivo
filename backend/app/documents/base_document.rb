require "prawn"
require "prawn/table"

# Plantilla maestra de los informes en PDF (sistema de diseño premium del brief).
# Dibuja el membrete white-label del club + el pie con folio/paginación en cada página,
# y expone helpers reusables (stat strip, tablas con hairlines, status pills, secciones).
# Las subclases solo implementan `cuerpo(pdf)`.
class BaseDocument
  include ReportTokens

  # tipo_doc: texto que se muestra en el membrete ("INFORME REPROCANN")
  # tipo_code: código corto para el folio ("RPC")
  def initialize(club:, usuario:, titulo:, tipo_doc: nil, tipo_code: "DOC", subtitulo: nil, folio: nil)
    @club      = club
    @usuario   = usuario
    @titulo    = titulo
    @tipo_doc  = tipo_doc || titulo
    @subtitulo = subtitulo
    @folio     = folio || generar_folio(tipo_code)
  end

  attr_reader :folio

  def render
    @pdf = Prawn::Document.new(
      page_size: "A4",
      margin:    [MARGIN_TOP, MARGIN_LR, MARGIN_BOT, MARGIN_LR],
    )
    ReportTokens.register_fonts(@pdf)
    @pdf.font SANS
    @pdf.fill_color INK
    dibujar_membrete
    dibujar_pie
    cuerpo(@pdf)
    @pdf.render
  end

  def cuerpo(_pdf)
    raise NotImplementedError, "#{self.class} debe implementar #cuerpo"
  end

  private

  def generar_folio(code)
    "CC-#{code}-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(2).upcase}"
  end

  # ── Membrete (repetido en todas las páginas, coordenadas absolutas) ──
  def dibujar_membrete
    @pdf.repeat(:all) do
      @pdf.canvas do
        ancho = @pdf.bounds.right
        alto  = @pdf.bounds.top

        # Banda superior verde bosque
        @pdf.fill_color FOREST
        @pdf.fill_rectangle [0, alto], ancho, 5

        y = alto - 30
        x = MARGIN_LR

        # Logo del club
        if logo_io
          begin
            @pdf.image logo_io, at: [x, y + 8], fit: [38, 38]
            logo_io.rewind
            x += 50
          rescue => e
            Rails.logger.warn "BaseDocument: logo no dibujado (#{e.message})"
          end
        end

        # Nombre del club (serif, institucional) + datos legales (mono)
        @pdf.fill_color FOREST
        @pdf.font(SERIF, style: :bold) do
          @pdf.text_box @club.name.to_s, at: [x, y + 10], width: 300, size: 13, overflow: :shrink_to_fit
        end
        @pdf.fill_color GRAY
        @pdf.font(MONO) do
          @pdf.text_box datos_legales, at: [x, y - 6], width: 320, size: 7, leading: 1.5
        end

        # Bloque derecho: tipo de informe + emisión + folio (respeta margen derecho)
        rb_w = 260
        rx   = ancho - MARGIN_LR - rb_w
        @pdf.fill_color INK
        @pdf.font(SANS, style: :bold) do
          @pdf.text_box @tipo_doc.to_s.upcase, at: [rx, y + 10], width: rb_w, align: :right, size: 11, character_spacing: 0.3
        end
        @pdf.fill_color GRAY
        @pdf.font(MONO) do
          meta = "Emitido: #{Time.current.strftime('%d/%m/%Y %H:%M')}\nFolio: #{@folio}"
          @pdf.text_box meta, at: [rx, y - 8], width: rb_w, align: :right, size: 7, leading: 1.5
        end

        # Regla verde bajo el membrete
        @pdf.stroke_color BRAND
        @pdf.line_width 0.9
        @pdf.stroke_horizontal_line MARGIN_LR, ancho - MARGIN_LR, at: alto - MARGIN_TOP + 24

        @pdf.fill_color INK
        @pdf.stroke_color "000000"
      end
    end
  end

  # ── Pie (hairline + nota legal + folio + Página N) ──
  def dibujar_pie
    @pdf.repeat(:all, dynamic: true) do
      @pdf.canvas do
        ancho = @pdf.bounds.right
        @pdf.stroke_color LINE
        @pdf.line_width 0.5
        @pdf.stroke_horizontal_line MARGIN_LR, ancho - MARGIN_LR, at: 42
        @pdf.fill_color GRAY
        @pdf.font(SANS) do
          @pdf.text_box "Confidencial · Generado vía Cultivo Espacial",
                        at: [MARGIN_LR, 33], width: 190, size: 6.5, overflow: :truncate
        end
        @pdf.font(MONO) do
          @pdf.text_box @folio, at: [275, 33], width: 150, align: :center, size: 7
          @pdf.text_box "Página #{@pdf.page_number}", at: [ancho - MARGIN_LR - 90, 33], width: 90, align: :right, size: 7
        end
        @pdf.fill_color INK
        @pdf.stroke_color "000000"
      end
    end
  end

  def datos_legales
    partes = []
    partes << "CUIT #{@club.cuit}" if @club.respond_to?(:cuit) && @club.cuit.present?
    if @club.respond_to?(:numero_resolucion_reprocann) && @club.numero_resolucion_reprocann.present?
      partes << "Resol. REPROCANN N.º #{@club.numero_resolucion_reprocann}"
    end
    partes.join("\n")
  end

  def logo_io
    return @logo_io if defined?(@logo_io)
    @logo_io = (@club.logo.attached? ? StringIO.new(@club.logo.download) : nil)
  rescue => e
    Rails.logger.warn "BaseDocument: logo no descargado (#{e.message})"
    @logo_io = nil
  end

  # ───────────────────────── Helpers de cuerpo reusables ─────────────────────────

  # Título de sección con regla fina debajo
  def titulo_seccion(pdf, texto)
    pdf.move_down 10
    pdf.fill_color FOREST
    pdf.font(SANS, style: :bold) { pdf.text texto.upcase, size: 10, character_spacing: 0.5 }
    pdf.move_down 3
    pdf.stroke_color LINE
    pdf.line_width 0.5
    pdf.stroke_horizontal_line 0, pdf.bounds.width, at: pdf.cursor
    pdf.fill_color INK
    pdf.move_down 8
  end

  # Stat strip austero: fila bordeada con N celdas (label arriba, número grande abajo)
  # items: [{ label:, valor:, tono: (:ok|:warn|:crit|nil) }]
  def stat_strip(pdf, items)
    return if items.empty?
    h = 48
    w = pdf.bounds.width
    cw = w / items.size.to_f
    y0 = pdf.cursor

    pdf.stroke_color LINE
    pdf.line_width 0.5
    pdf.stroke_rounded_rectangle [0, y0], w, h, 5

    items.each_with_index do |it, i|
      x = i * cw
      # separador vertical
      if i.positive?
        pdf.stroke_color LINE
        pdf.stroke_vertical_line y0 - 8, y0 - h + 8, at: x
      end
      pdf.fill_color GRAY
      pdf.font(SANS) { pdf.text_box it[:label].to_s.upcase, at: [x + 10, y0 - 9], width: cw - 16, size: 6.5, character_spacing: 0.4 }
      pdf.fill_color tono_color(it[:tono]) || FOREST
      pdf.font(SANS, style: :bold) { pdf.text_box it[:valor].to_s, at: [x + 10, y0 - 22], width: cw - 16, size: 19 }
    end
    pdf.fill_color INK
    pdf.stroke_color "000000"
    pdf.move_down h + 6
  end

  # Tabla premium: header verde, hairlines horizontales, zebra suave, números en mono.
  # headers: [..], rows: [[..], ..]
  # opts: { aligns: {idx => :right}, mono: [idx,..], col_widths: {idx => w},
  #         status_col: idx, status_levels: [..] (mismo largo que rows) }
  def styled_table(pdf, headers, rows, opts = {})
    aligns     = opts[:aligns] || {}
    mono_cols  = opts[:mono] || []
    status_col = opts[:status_col]
    levels     = opts[:status_levels] || []

    data = [headers] + rows
    tbl = pdf.make_table(data, width: pdf.bounds.width, header: true, column_widths: opts[:col_widths]) do |t|
      t.cells.borders      = [:bottom]
      t.cells.border_color = LINE
      t.cells.border_width = 0.5
      t.cells.padding      = [5, 7]
      t.cells.size         = 8.5
      t.cells.font         = SANS

      # Header
      t.row(0).background_color = FOREST
      t.row(0).text_color       = WHITE
      t.row(0).font_style       = :bold
      t.row(0).size             = 8
      t.row(0).borders          = []

      # Zebra (filas de datos, 1..n)
      (1...data.size).each { |r| t.row(r).background_color = r.even? ? ZEBRA : WHITE }

      # Alineación + mono por columna
      aligns.each   { |idx, a| t.column(idx).align = a }
      mono_cols.each { |idx| t.column(idx).font = MONO }
    end

    # Color del texto de la columna de estado por nivel (semáforo)
    if status_col && levels.any?
      levels.each_with_index do |lvl, i|
        cell = tbl.row(i + 1).column(status_col)
        cell.text_color = tono_color(lvl) || INK
        cell.font_style = :bold
      end
    end

    tbl.draw
  end

  # Texto de estado con punto de color (sobrevive a B/N por el texto)
  def estado_con_punto(label)
    "#{label}"
  end

  def tono_color(tono)
    { ok: OK, warn: WARN, crit: CRIT, vencido: CRIT, por_vencer: WARN, vigente: OK }[tono&.to_sym]
  end

  def nota_pie(pdf, texto)
    pdf.move_down 8
    pdf.fill_color GRAY
    pdf.font(SANS) { pdf.text texto, size: 7, leading: 1.5 }
    pdf.fill_color INK
  end
end
