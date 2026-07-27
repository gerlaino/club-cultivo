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

// CSS de una etiqueta. La caja mide 80×50mm y no se parte entre páginas.
export const etiquetaLoteCSS = `
  * { box-sizing: border-box; margin: 0; padding: 0; }
  .et-lote {
    display: flex; align-items: center; gap: 4mm;
    width: 80mm; height: 50mm; padding: 4mm;
    border: 0.3mm solid #bbb; border-radius: 3mm; background: #fff;
    page-break-inside: avoid; break-inside: avoid;
    font-family: -apple-system, system-ui, sans-serif;
  }
  .et-lote-qr { width: 30mm; height: 30mm; flex-shrink: 0; display: block; }
  .et-lote-info { display: flex; flex-direction: column; gap: 1mm; min-width: 0; overflow: hidden; }
  .et-lote-code { font-family: monospace; font-size: 14pt; font-weight: 800; color: #0f172a; line-height: 1.1; }
  .et-lote-gen { font-size: 10.5pt; font-weight: 700; color: #15803d; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .et-lote-meta { font-size: 8.5pt; color: #475569; }
  .et-lote-club { font-size: 7.5pt; color: #94a3b8; margin-top: 1mm; }
`

/** Hoja de UNA etiqueta sola (el botón del detalle imprime una sola, centrada). */
export const hojaUnaEtiquetaCSS = `
  ${etiquetaLoteCSS}
  @page { size: 80mm 50mm; margin: 0; }
  body { display: flex; align-items: center; justify-content: center; min-height: 100vh; }
  .hoja { display: flex; }
  .et-lote { border: 0; }
`

/** Hoja A4 en tanda: 2 columnas × 5 filas = 10 etiquetas por página. */
export const hojaTandaCSS = `
  ${etiquetaLoteCSS}
  @page { size: A4; margin: 5mm; }
  body { background: #fff; }
  .hoja { display: flex; flex-wrap: wrap; gap: 2mm; align-content: flex-start; }
`
