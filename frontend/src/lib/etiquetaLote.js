// Etiqueta de LOTE (80×50mm): QR + código + genética + estado + inicio + plantas + club.
// Fuente única: la usa el botón "QR lote" del detalle y la impresión en tanda desde /lotes. Antes el
// HTML vivía inline en LoteDetailView, así que una tanda hecha aparte habría divergido a la primera
// corrección. Hermana de lib/etiquetaPlanta.js (la banderita plegable de planta).

function esc(s) {
  return String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]))
}

function fechaCorta(d) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(d ?? ''))
  return m ? `${m[3]}/${m[2]}/${m[1]}` : null
}

/**
 * HTML de UNA etiqueta de lote.
 * @param {Object} d { qrDataUrl, codigo, genetica, estado, inicio, plantas, clubName }
 */
export function etiquetaLoteHTML(d) {
  const inicio = fechaCorta(d.inicio)
  return `<div class="et-lote">
  <img class="et-lote-qr" src="${d.qrDataUrl}" alt="${esc(d.codigo)}" />
  <div class="et-lote-info">
    <div class="et-lote-code">${esc(d.codigo)}</div>
    <div class="et-lote-gen">🌿 ${esc(d.genetica || '—')}</div>
    <div class="et-lote-meta">${esc(d.estado || '—')}${inicio ? ` · inicio ${esc(inicio)}` : ''}</div>
    <div class="et-lote-meta">${d.plantas ?? 0} plantas</div>
    <div class="et-lote-club">${esc(d.clubName || '')}</div>
  </div>
</div>`
}

// Medidas de la etiqueta, en un solo lugar (las usa el layout de la hoja para que entren 3 por fila).
export const ET_ANCHO_MM = 93
export const ET_ALTO_MM  = 60

// CSS de una etiqueta. No se parte entre páginas.
// El nombre de la genética **envuelve hasta 2 líneas** en vez de cortarse con "…": los nombres
// reales son largos ("Lemonesia - Tropicanna") y una etiqueta que dice "Lemonesia - Tro…" no sirve
// para identificar el lote en el pasillo, que es todo el punto de la etiqueta.
export const etiquetaLoteCSS = `
  * { box-sizing: border-box; margin: 0; padding: 0; }
  .et-lote {
    display: flex; align-items: center; gap: 5mm;
    width: ${ET_ANCHO_MM}mm; height: ${ET_ALTO_MM}mm; padding: 5mm;
    border: 0.3mm solid #bbb; border-radius: 3mm; background: #fff;
    page-break-inside: avoid; break-inside: avoid;
    font-family: -apple-system, system-ui, sans-serif;
  }
  .et-lote-qr { width: 36mm; height: 36mm; flex-shrink: 0; display: block; }
  .et-lote-info { display: flex; flex-direction: column; gap: 1.2mm; min-width: 0; }
  .et-lote-code { font-family: monospace; font-size: 17pt; font-weight: 800; color: #0f172a; line-height: 1.1; }
  .et-lote-gen {
    font-size: 12pt; font-weight: 700; color: #15803d; line-height: 1.15;
    display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
    overflow: hidden; overflow-wrap: anywhere;
  }
  .et-lote-meta { font-size: 9.5pt; color: #475569; }
  .et-lote-club { font-size: 8pt; color: #94a3b8; margin-top: 1mm; }
`

/** Hoja de UNA etiqueta sola (el botón del detalle imprime una, centrada). */
export const hojaUnaEtiquetaCSS = `
  ${etiquetaLoteCSS}
  @page { size: ${ET_ANCHO_MM}mm ${ET_ALTO_MM}mm; margin: 0; }
  body { display: flex; align-items: center; justify-content: center; min-height: 100vh; }
  .hoja { display: flex; }
  .et-lote { border: 0; }
`

/**
 * Hoja en tanda: **A4 apaisada, 3 etiquetas por fila × 3 filas = 9 por página**.
 * Con etiquetas de 93mm, 3 por fila necesitan 283mm de ancho: en A4 vertical (200mm útiles) solo
 * entrarían 2. Apaisada hay 287mm útiles y entran las 3 sin achicar la etiqueta.
 *
 * `.hoja` tiene el ancho de la página a propósito: el HTML descargado se ve en el navegador igual
 * que impreso. Sin ese ancho el flex-wrap usaba el ancho de la ventana y en pantalla aparecían 6
 * por fila, que no era lo que iba a salir por la impresora.
 */
export const hojaTandaCSS = `
  ${etiquetaLoteCSS}
  @page { size: A4 landscape; margin: 5mm; }
  body { background: #fff; display: flex; justify-content: center; }
  .hoja {
    display: flex; flex-wrap: wrap; gap: 2mm;
    width: 287mm; align-content: flex-start;
  }
`
