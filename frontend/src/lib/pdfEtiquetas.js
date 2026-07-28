// Etiquetas QR en PDF, dibujadas en MILÍMETROS con primitivas de jsPDF.
//
// Por qué PDF y no la hoja HTML que había antes: en el HTML los milímetros son una sugerencia — el
// diálogo de impresión de Chrome aplica su "ajustar a la página" y te encoge todo un 3-5%, que con
// planchas autoadhesivas te arruina el calce. En el PDF la geometría queda clavada y se imprime
// igual en cualquier máquina.
//
// Y se dibuja con primitivas en vez de rasterizar el HTML (html2pdf/html2canvas): el texto queda
// vectorial, el archivo pesa una fracción, y con 800 etiquetas html2canvas se arrastra.
//
// Ojo con los EMOJI: las fuentes estándar del PDF (helvetica/courier) no los tienen, así que acá no
// va ningún 🌿 — se reemplaza por tipografía. Los acentos y la ñ sí funcionan (WinAnsi).

const VERDE  = [21, 128, 61]
const TINTA  = [15, 23, 42]
const GRIS   = [71, 85, 105]
const GRIS_2 = [148, 163, 184]
const BORDE  = [190, 190, 190]

/** Recorta a `max` líneas lo que jsPDF haya partido, agregando … si sobró. */
function lineasAcotadas(doc, texto, ancho, max) {
  const lineas = doc.splitTextToSize(String(texto ?? ''), ancho)
  if (lineas.length <= max) return lineas
  const cortadas = lineas.slice(0, max)
  cortadas[max - 1] = `${cortadas[max - 1].replace(/[\s.]+$/, '')}…`
  return cortadas
}

function fechaCorta(d) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(d ?? ''))
  return m ? `${m[3]}/${m[2]}/${m[1]}` : null
}

// ─── Etiqueta de LOTE ───────────────────────────────────────────────────────────
// 93×60mm, 3 por fila en A4 apaisada (3 × 93 + gaps = 283 ≤ 287 útiles) → 9 por página.
// En A4 vertical (200mm útiles) solo entrarían 2, y achicarla para meter 3 deja el nombre de la
// genética ilegible, que es justo lo que hay que poder leer en el pasillo.
export const LAYOUT_LOTE = {
  orientacion: 'landscape',
  ancho: 93,
  alto: 60,
  gap: 2,
  margen: 5,
  qrPx: 300,
}

export function dibujarEtiquetaLote(doc, x, y, d) {
  const { ancho, alto } = LAYOUT_LOTE
  const pad = 5
  const qr  = 36

  doc.setDrawColor(...BORDE)
  doc.setLineWidth(0.2)
  doc.roundedRect(x, y, ancho, alto, 3, 3)

  doc.addImage(d.qrDataUrl, 'PNG', x + pad, y + (alto - qr) / 2, qr, qr, undefined, 'FAST')

  const tx = x + pad + qr + 5
  const tw = ancho - (pad + qr + 5) - pad
  let cy = y + 19

  doc.setFont('courier', 'bold'); doc.setFontSize(17); doc.setTextColor(...TINTA)
  doc.text(String(d.codigo ?? ''), tx, cy)

  cy += 8
  doc.setFont('helvetica', 'bold'); doc.setFontSize(12); doc.setTextColor(...VERDE)
  for (const linea of lineasAcotadas(doc, d.genetica || '—', tw, 2)) {
    doc.text(linea, tx, cy)
    cy += 5
  }

  cy += 2.5
  const inicio = fechaCorta(d.inicio)
  doc.setFont('helvetica', 'normal'); doc.setFontSize(9.5); doc.setTextColor(...GRIS)
  doc.text(`${d.estado || '—'}${inicio ? ` · inicio ${inicio}` : ''}`, tx, cy)
  cy += 5
  doc.text(`${d.plantas ?? 0} plantas`, tx, cy)

  if (d.clubName) {
    doc.setFontSize(8); doc.setTextColor(...GRIS_2)
    doc.text(String(d.clubName), tx, y + alto - pad)
  }
}

// ─── Banderita de PLANTA (plegable, doble faz) ──────────────────────────────────
// 160×26mm con DOS mitades idénticas y una línea de plegado en el medio: al plegar la tira sobre el
// tronco quedan QR + info legibles de los dos lados. 1 por fila en A4 vertical → 10 por página.
export const LAYOUT_PLANTA = {
  orientacion: 'portrait',
  ancho: 160,
  alto: 26,
  gap: 2,
  margen: 8,
  qrPx: 220,
}

function dibujarMitadPlanta(doc, x, y, d) {
  const alto = LAYOUT_PLANTA.alto
  const pad  = 3
  const qr   = 20

  doc.addImage(d.qrDataUrl, 'PNG', x + pad + 1, y + (alto - qr) / 2, qr, qr, undefined, 'FAST')

  const tx = x + pad + 1 + qr + 3
  const tw = LAYOUT_PLANTA.ancho / 2 - (tx - x) - pad
  let cy = y + 7

  if (d.clubName) {
    doc.setFont('helvetica', 'bold'); doc.setFontSize(6); doc.setTextColor(...VERDE)
    doc.text(lineasAcotadas(doc, d.clubName, tw, 1)[0], tx, cy)
  }

  cy += 4.5
  doc.setFont('courier', 'bold'); doc.setFontSize(8.5); doc.setTextColor(...TINTA)
  doc.text(lineasAcotadas(doc, d.nombre || '—', tw, 1)[0], tx, cy)

  cy += 4.5
  doc.setFont('helvetica', 'bold'); doc.setFontSize(7.5); doc.setTextColor(...VERDE)
  doc.text(lineasAcotadas(doc, d.genetica || '—', tw, 1)[0], tx, cy)

  cy += 4
  doc.setFont('helvetica', 'normal'); doc.setFontSize(6.5); doc.setTextColor(...GRIS)
  const inicio = fechaCorta(d.inicio)
  doc.text(`Lote ${d.lote || '—'}${inicio ? ` · ${inicio}` : ''}`, tx, cy)
}

export function dibujarBanderitaPlanta(doc, x, y, d) {
  const { ancho, alto } = LAYOUT_PLANTA
  const mitad = ancho / 2

  doc.setDrawColor(...BORDE)
  doc.setLineWidth(0.2)
  doc.roundedRect(x, y, ancho, alto, 2, 2)

  dibujarMitadPlanta(doc, x, y, d)
  dibujarMitadPlanta(doc, x + mitad, y, d)

  // Línea de plegado, punteada, en el medio.
  doc.setLineDashPattern([1, 1], 0)
  doc.setDrawColor(180, 180, 180)
  doc.line(x + mitad, y + 2, x + mitad, y + alto - 2)
  doc.setLineDashPattern([], 0)
}

/** Cuántas columnas y filas entran por página con un layout dado (para tests y para el paginado). */
export function grillaDe(layout, pagina) {
  const utilAncho = pagina.ancho - layout.margen * 2
  const utilAlto  = pagina.alto  - layout.margen * 2
  const cols = Math.max(1, Math.floor((utilAncho + layout.gap) / (layout.ancho + layout.gap)))
  const filas = Math.max(1, Math.floor((utilAlto + layout.gap) / (layout.alto + layout.gap)))
  return { cols, filas, porPagina: cols * filas }
}

export const A4 = {
  portrait:  { ancho: 210, alto: 297 },
  landscape: { ancho: 297, alto: 210 },
}
