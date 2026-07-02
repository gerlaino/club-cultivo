// Banderita de planta PLEGABLE (doble faz). La etiqueta tiene dos copias IDÉNTICAS de
// QR+info, una al lado de la otra, separadas por una línea de plegado en el medio. Al
// plegar la tira sobre el tronco quedan QR+info legibles de ambos lados. Hay margen de
// blanco en el medio (zona de plegado) y en los bordes para que el QR tenga lectura
// limpia (quiet zone) sin verse afectado.

function esc(s) {
  return String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]))
}

// Datos de una etiqueta: { qrDataUrl, nombre, genetica, lote, inicio, clubName, clubLogo }
function media(d) {
  const logo = d.clubLogo ? `<img src="${esc(d.clubLogo)}" alt="" />` : ''
  return `
      <img class="et-qr" src="${d.qrDataUrl}" alt="${esc(d.nombre)}" />
      <div class="et-info">
        <div class="et-club">${logo}${esc(d.clubName)}</div>
        <div class="et-code">${esc(d.nombre)}</div>
        <div class="et-gen">🌿 ${esc(d.genetica || '—')}</div>
        <div class="et-meta">Lote ${esc(d.lote || '—')}${d.inicio ? ` · ${esc(d.inicio)}` : ''}</div>
      </div>`
}

// Devuelve el HTML de UNA banderita plegable (el <div class="et">…</div>).
export function banderitaHTML(d) {
  const half = media(d)
  return `<div class="et"><div class="et-half">${half}</div><div class="et-fold"></div><div class="et-half">${half}</div></div>`
}

// CSS compartido (individual + batch). La tira mide 160×26mm; se pliega en el medio.
export const banderitaCSS = `
  * { box-sizing: border-box; margin: 0; padding: 0; }
  .et { display: flex; width: 160mm; height: 26mm; border: 0.3mm solid #ddd; border-radius: 2mm; overflow: hidden; page-break-inside: avoid; break-inside: avoid; background: #fff; }
  .et-half { flex: 1; display: flex; align-items: center; gap: 3mm; padding: 3mm 4mm; min-width: 0; }
  .et-fold { width: 0; margin: 0 4mm; border-left: 0.3mm dashed #bbb; }
  .et-qr { width: 20mm; height: 20mm; flex-shrink: 0; display: block; }
  .et-info { display: flex; flex-direction: column; gap: .4mm; min-width: 0; overflow: hidden; }
  .et-club { display: flex; align-items: center; gap: 1mm; font-size: 6pt; font-weight: 700; color: #15803d; }
  .et-club img { height: 4mm; width: auto; object-fit: contain; }
  .et-code { font-family: monospace; font-size: 8.5pt; font-weight: 800; color: #0f172a; line-height: 1.1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .et-gen { font-size: 7.5pt; font-weight: 600; color: #15803d; line-height: 1.15; }
  .et-meta { font-size: 6.5pt; color: #475569; line-height: 1.2; }
`
