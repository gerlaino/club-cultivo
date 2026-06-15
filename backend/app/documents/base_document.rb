require "prawn"
require "prawn/table"

# Plantilla maestra de los informes en PDF. Dibuja el membrete institucional del
# club (logo + datos legales) y el pie (paginación + emisión) en todas las páginas.
# Las subclases solo implementan `cuerpo(pdf)`.
#
#   class MiInforme < BaseDocument
#     def cuerpo(pdf)
#       pdf.text "contenido…"
#     end
#   end
#   MiInforme.new(club:, usuario:, titulo: "Mi informe").render  # => String (bytes PDF)
class BaseDocument
  VERDE       = "15803D"
  VERDE_OSC   = "0F3D20"
  GRIS        = "64748B"
  GRIS_CLARO  = "94A3B8"
  LINEA       = "D4E6D4"
  TINTA       = "0F172A"

  FUENTE      = "DejaVu"  # TTF vendorizada en vendor/fonts (UTF-8 completo)
  FONT_DIR    = Rails.root.join("vendor", "fonts")

  def initialize(club:, usuario:, titulo:, subtitulo: nil)
    @club      = club
    @usuario   = usuario
    @titulo    = titulo
    @subtitulo = subtitulo
  end

  # Devuelve los bytes del PDF
  def render
    @pdf = Prawn::Document.new(
      page_size: "A4",
      margin:    [128, 45, 64, 45], # top alto para el membrete, bottom para el pie
    )
    @pdf.font_families.update(FUENTE => {
      normal: FONT_DIR.join("DejaVuSans.ttf").to_s,
      bold:   FONT_DIR.join("DejaVuSans-Bold.ttf").to_s,
    })
    @pdf.font FUENTE
    dibujar_membrete
    dibujar_pie
    @pdf.fill_color TINTA
    cuerpo(@pdf)
    @pdf.render
  end

  # Las subclases implementan el cuerpo
  def cuerpo(_pdf)
    raise NotImplementedError, "#{self.class} debe implementar #cuerpo"
  end

  private

  # Membrete repetido en todas las páginas (coordenadas absolutas vía canvas)
  def dibujar_membrete
    @pdf.repeat(:all) do
      @pdf.canvas do
        ancho = @pdf.bounds.right
        alto  = @pdf.bounds.top

        # Banda superior verde
        @pdf.fill_color VERDE
        @pdf.fill_rectangle [0, alto], ancho, 6

        y = alto - 26
        x = 45

        # Logo del club (si tiene)
        if logo_io
          begin
            @pdf.image logo_io, at: [x, y + 6], fit: [44, 44]
            logo_io.rewind
            x += 56
          rescue => e
            Rails.logger.warn "BaseDocument: logo no dibujado (#{e.message})"
          end
        end

        # Nombre + datos legales del club
        @pdf.fill_color VERDE_OSC
        @pdf.font(FUENTE, style: :bold) do
          @pdf.text_box @club.name.to_s, at: [x, y + 8], width: 300, size: 13, overflow: :shrink_to_fit
        end
        @pdf.fill_color GRIS
        @pdf.font(FUENTE) do
          @pdf.text_box datos_legales, at: [x, y - 9], width: 320, size: 7.5
        end

        # Título del informe (derecha)
        @pdf.fill_color GRIS_CLARO
        @pdf.font(FUENTE, style: :bold) do
          @pdf.text_box @titulo.to_s.upcase, at: [ancho - 295, y + 8], width: 250, align: :right, size: 11
        end
        if @subtitulo.present?
          @pdf.fill_color GRIS_CLARO
          @pdf.font(FUENTE) do
            @pdf.text_box @subtitulo.to_s, at: [ancho - 295, y - 8], width: 250, align: :right, size: 8
          end
        end

        # Línea separadora bajo el membrete
        @pdf.stroke_color LINEA
        @pdf.line_width 0.8
        @pdf.stroke_horizontal_line 45, ancho - 45, at: alto - 78

        @pdf.fill_color TINTA
        @pdf.stroke_color "000000"
      end
    end
  end

  def dibujar_pie
    @pdf.repeat(:all, dynamic: true) do
      @pdf.canvas do
        ancho = @pdf.bounds.right
        @pdf.stroke_color LINEA
        @pdf.line_width 0.8
        @pdf.stroke_horizontal_line 45, ancho - 45, at: 46
        @pdf.fill_color GRIS_CLARO
        @pdf.font(FUENTE) do
          @pdf.text_box pie_texto, at: [45, 38], width: ancho - 200, size: 6.8
          @pdf.text_box "Página #{@pdf.page_number}", at: [ancho - 145, 38], width: 100, align: :right, size: 6.8
        end
        @pdf.fill_color TINTA
        @pdf.stroke_color "000000"
      end
    end
  end

  def datos_legales
    partes = []
    partes << @club.legal_name if @club.respond_to?(:legal_name) && @club.legal_name.present? && @club.legal_name != @club.name
    partes << "CUIT #{@club.cuit}" if @club.respond_to?(:cuit) && @club.cuit.present?
    if @club.respond_to?(:numero_resolucion_reprocann) && @club.numero_resolucion_reprocann.present?
      partes << "Res. REPROCANN #{@club.numero_resolucion_reprocann}"
    end
    partes.join("   ·   ")
  end

  def pie_texto
    quien = if @usuario.respond_to?(:nombre_completo) && @usuario.nombre_completo.present?
      @usuario.nombre_completo
    else
      @usuario&.email
    end
    "Emitido el #{Time.current.strftime('%d/%m/%Y a las %H:%M')} por #{quien} · Generado por Cultivo Espacial"
  end

  def logo_io
    return @logo_io if defined?(@logo_io)
    @logo_io = (@club.logo.attached? ? StringIO.new(@club.logo.download) : nil)
  rescue => e
    Rails.logger.warn "BaseDocument: logo no descargado (#{e.message})"
    @logo_io = nil
  end

  # Helpers de cuerpo reutilizables por las subclases ----------------------

  def titulo_seccion(pdf, texto)
    pdf.move_down 6
    pdf.fill_color VERDE_OSC
    pdf.font(FUENTE, style: :bold) { pdf.text texto, size: 11 }
    pdf.fill_color TINTA
    pdf.move_down 4
  end
end
