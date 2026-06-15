# Tokens de diseño del sistema de informes (un único lugar).
# Basado en el brief de diseño: identidad cannabis sobria (apothecary), credibilidad
# regulatoria, color por lógica y no decorativo.
#
# Fuentes: hoy DejaVu (Serif/Sans/Mono) — da los 3 roles tipográficos. Para pasar a
# IBM Plex en el futuro, basta reemplazar los .ttf en vendor/fonts y los nombres acá.
module ReportTokens
  # ── Verdes de marca (sobrios, no flúor) ──
  FOREST     = "14532D" # verde bosque institucional (headers de tabla, banda, sello)
  BRAND      = "2D6A4F" # verde Cultivo primario (regla membrete, acentos, KPI)
  SAGE       = "E3EDE7" # verde salvia claro (fondo header tabla / tarjeta KPI)
  SAGE_FAINT = "F1F6F3" # salvia tenue (zebra suave)

  # ── Neutros (la base real del documento) ──
  INK        = "1A1A1A" # texto principal (negro suave)
  GRAY       = "5A5A5A" # secundario, labels, notas
  LINE       = "E2E2E2" # hairlines de tablas y separadores
  ZEBRA      = "F7F8F7" # fila alterna neutra
  WHITE      = "FFFFFF"

  # ── Semáforo de estado (terroso, sobrio) ──
  OK         = "2E7D5B" # vigente / cumple
  WARN       = "B45309" # por vencer / atención (ámbar apagado)
  CRIT       = "9B2C2C" # vencido / no cumple (rojo ladrillo)
  SEAL       = "8A6D3B" # dorado/latón apagado (sello verificación)

  # ── Layout A4 (en puntos) ──
  MARGIN_LR  = 54
  MARGIN_TOP = 128 # deja lugar al membrete
  MARGIN_BOT = 60  # deja lugar al pie

  # ── Fuentes (3 roles) ──
  SERIF = "ReportSerif"
  SANS  = "ReportSans"
  MONO  = "ReportMono"

  FONT_DIR = Rails.root.join("vendor", "fonts")
  FONT_FILES = {
    SERIF => { normal: "DejaVuSerif.ttf",    bold: "DejaVuSerif-Bold.ttf" },
    SANS  => { normal: "DejaVuSans.ttf",     bold: "DejaVuSans-Bold.ttf" },
    MONO  => { normal: "DejaVuSansMono.ttf", bold: "DejaVuSansMono-Bold.ttf" },
  }.freeze

  def self.register_fonts(pdf)
    FONT_FILES.each do |family, files|
      pdf.font_families.update(family => {
        normal: FONT_DIR.join(files[:normal]).to_s,
        bold:   FONT_DIR.join(files[:bold]).to_s,
      })
    end
  end
end
