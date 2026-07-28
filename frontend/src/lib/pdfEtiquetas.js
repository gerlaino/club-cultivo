// Impresos en PDF —etiquetas de lote, banderitas de planta y entradas de evento—, dibujados en
// MILÍMETROS con primitivas de jsPDF.
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

// Opciones del QR, por pieza. Dos decisiones que no son estéticas:
//
// • `errorCorrectionLevel: 'H'` — tolera 30% del código dañado, contra el 15% del default ('M').
//   Estas etiquetas viven en un cuarto de cultivo: se humedecen, se manchan de solución nutritiva,
//   se pliegan y se rayan. Con 'M', una esquina comida ya deja de leer.
// • `margin: 2` — la zona muda. Si el borde se ensucia o se dobla, un margen generoso salva la
//   lectura; con margen 1 el lector pierde el patrón de posición.
//
// El COLOR sí cambia según dónde vive la pieza: la banderita de planta va en negro, que es el que
// más contraste da y el que mejor aguanta un material húmedo o un tóner rayado. La etiqueta de lote
// y la entrada van en verde: viven en lugares protegidos y ahí gana la marca.
const QR_BASE = { margin: 2, errorCorrectionLevel: 'H', color: { dark: '#1b5e20', light: '#ffffff' } }
const QR_NEGRO = { ...QR_BASE, color: { dark: '#000000', light: '#ffffff' } }

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
  qr: { ...QR_BASE, width: 300 },
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
  qr: { ...QR_NEGRO, width: 220 },   // la que más sufre: negro
}

function dibujarMitadPlanta(doc, x, y, d) {
  const alto = LAYOUT_PLANTA.alto
  const pad  = 3
  // 21mm y no 20: con corrección de error H el código pasa a 41×41 módulos, y en 20mm cada módulo
  // queda en 0,44mm — al borde de lo que una cámara de celular resuelve cómodo. Con 21 vuelve a
  // ~0,47mm. Es preferible ganar ese milímetro que bajar la tolerancia al daño, que es justo lo que
  // necesitamos en una etiqueta que se moja.
  const qr   = 21

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

// ─── ENTRADA de evento ──────────────────────────────────────────────────────────
// 180×70mm, 3 por A4 vertical. Cuerpo + TALÓN troquelado a la derecha con el QR y el código: en la
// puerta se corta por la línea punteada y el talón queda de comprobante.
//
// Está pensada como **invitación / pase**, no como ticket comercial: lo que manda es el EVENTO, la
// FECHA y el HORARIO. El precio va chiquito y solo si lo hay — al que la recibe no le importa
// cuánto salió, le importa a qué va, cuándo y a qué hora. Una entrada sin cargo simplemente no
// menciona plata en ningún lado.
//
// Genérica a propósito: sirve para cualquier evento de cualquier club. Lo único que la "marca" es
// el nombre del club y la franja de color del borde izquierdo.
export const LAYOUT_ENTRADA = {
  orientacion: 'portrait',
  ancho: 180,
  alto: 70,
  gap: 4,
  margen: 10,
  qr: { ...QR_BASE, width: 320 },
}

const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
               'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
const MESES_CORTO = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
                     'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC']

/** Partes de una fecha ISO, sin toLocaleDateString (depende del locale de la máquina que abre). */
function partesFecha(d) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(d ?? ''))
  if (!m) return null
  return { dia: Number(m[3]), mes: Number(m[2]), anio: m[1] }
}
function fechaLarga(d) {
  const p = partesFecha(d)
  return p ? `${p.dia} de ${MESES[p.mes - 1]} de ${p.anio}` : null
}

export function dibujarEntrada(doc, x, y, d) {
  const { ancho, alto } = LAYOUT_ENTRADA
  const corte = x + ancho - 54      // dónde cae el troquel

  // Marco + franja de color en el canto izquierdo.
  doc.setDrawColor(...BORDE)
  doc.setLineWidth(0.2)
  doc.roundedRect(x, y, ancho, alto, 3, 3)
  doc.setFillColor(...VERDE)
  doc.rect(x + 1, y + 4, 2.5, alto - 8, 'F')

  // ── Bloque de fecha: lo primero que se lee, como en una invitación ──
  const p = partesFecha(d.fecha)
  const chip = { x: x + 9, y: y + 13, w: 24, h: 27 }
  doc.setFillColor(240, 249, 243)
  doc.roundedRect(chip.x, chip.y, chip.w, chip.h, 3, 3, 'F')
  const cxChip = chip.x + chip.w / 2
  if (p) {
    doc.setFont('helvetica', 'bold'); doc.setFontSize(20); doc.setTextColor(...VERDE)
    doc.text(String(p.dia), cxChip, chip.y + 13.5, { align: 'center' })
    doc.setFont('helvetica', 'bold'); doc.setFontSize(8); doc.setTextColor(...VERDE)
    doc.text(MESES_CORTO[p.mes - 1], cxChip, chip.y + 21, { align: 'center' })
  } else {
    doc.setFont('helvetica', 'bold'); doc.setFontSize(8); doc.setTextColor(...GRIS_2)
    doc.text('A', cxChip, chip.y + 13, { align: 'center' })
    doc.text('CONFIRMAR', cxChip, chip.y + 19, { align: 'center' })
  }

  // ── Cuerpo ──
  const tx = chip.x + chip.w + 7
  const tw = corte - tx - 6

  doc.setFont('helvetica', 'bold'); doc.setFontSize(18); doc.setTextColor(...TINTA)
  let cy = y + 21
  for (const linea of lineasAcotadas(doc, d.evento || 'Evento', tw, 2)) {
    doc.text(linea, tx, cy)
    cy += 7.5
  }

  if (d.clubName) {
    doc.setFont('helvetica', 'bold'); doc.setFontSize(9); doc.setTextColor(...VERDE)
    doc.text(lineasAcotadas(doc, d.clubName, tw, 1)[0], tx, cy + 1)
    cy += 6
  }

  doc.setFont('helvetica', 'normal'); doc.setFontSize(9.5); doc.setTextColor(...GRIS)
  const cuando = [fechaLarga(d.fecha), d.horario].filter(Boolean).join('  ·  ')
  doc.text(cuando || 'Fecha y horario a confirmar', tx, cy + 1)

  // ── Pie: a nombre de quién, y recién ahí el tipo y el precio, en chico ──
  const by = y + alto - 8
  if (d.comprador) {
    doc.setFont('helvetica', 'normal'); doc.setFontSize(8.5); doc.setTextColor(...GRIS)
    // Se le deja el ancho menos lo que ocupa el "tipo · precio" alineado a la derecha.
    doc.text(lineasAcotadas(doc, `A nombre de ${d.comprador}`, tw - 28, 1)[0], tx, by)
  }
  const precio = Number(d.precio)
  const menor = [d.tipo, precio > 0 ? `$${Math.round(precio).toLocaleString('es-AR')}` : null]
    .filter(Boolean).join('  ·  ')
  if (menor) {
    doc.setFont('helvetica', 'normal'); doc.setFontSize(7.5); doc.setTextColor(...GRIS_2)
    doc.text(menor, corte - 6, by, { align: 'right' })
  }

  // ── Troquel ──
  doc.setLineDashPattern([1.2, 1.2], 0)
  doc.setDrawColor(...GRIS_2)
  doc.line(corte, y + 4, corte, y + alto - 4)
  doc.setLineDashPattern([], 0)
  // Muescas: círculos blancos sin borde centrados en el canto, que "comen" el marco. Es lo que hace
  // que se lea como un ticket troquelado y no como una tabla partida al medio.
  doc.setFillColor(255, 255, 255)
  doc.circle(corte, y, 1.8, 'F')
  doc.circle(corte, y + alto, 1.8, 'F')

  // ── Talón ──
  const qr = 30
  const sx = corte + (54 - qr) / 2
  doc.addImage(d.qrDataUrl, 'PNG', sx, y + 9, qr, qr, undefined, 'FAST')

  doc.setFont('courier', 'bold'); doc.setFontSize(11); doc.setTextColor(...TINTA)
  doc.text(String(d.codigo || '').toUpperCase(), corte + 27, y + 46, { align: 'center' })

  doc.setFont('helvetica', 'bold'); doc.setFontSize(6.5); doc.setTextColor(...VERDE)
  doc.text('ACCESO', corte + 27, y + 53, { align: 'center' })
  doc.setFont('helvetica', 'normal'); doc.setFontSize(6); doc.setTextColor(...GRIS_2)
  doc.text('Mostralo en la puerta', corte + 27, y + 58, { align: 'center' })
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
