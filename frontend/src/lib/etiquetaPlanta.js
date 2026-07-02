// Banderita de planta PLEGABLE (doble faz). La etiqueta tiene dos copias de QR+info
// una al lado de la otra, separadas por una línea de plegado. La segunda copia va
// rotada 180°: al plegar la tira sobre el tronco (fold en el medio), ambas caras
// quedan legibles con QR + info. Así no queda blanco y se lee de los dos lados.
//
// El QR se lee igual rotado (los QR son invariantes a la rotación).

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
  return `<div class="et"><div class="et-half">${half}</div><div class="et-fold"></div><div class="et-half et-half--flip">${half}</div></div>`
}

// CSS compartido (individual + batch). La tira mide 140×25mm; se pliega en el medio.
export const banderitaCSS = `
  * { box-sizing: border-box; margin: 0; padding: 0; }
  .et { display: flex; width: 140mm; height: 25mm; border: 0.3mm solid #ddd; border-radius: 2mm; overflow: hidden; page-break-inside: avoid; break-inside: avoid; background: #fff; }
  .et-half { flex: 1; display: flex; align-items: center; gap: 2mm; padding: 2mm; min-width: 0; }
  .et-half--flip { transform: rotate(180deg); }
  .et-fold { width: 0; border-left: 0.3mm dashed #bbb; }
  .et-qr { width: 21mm; height: 21mm; flex-shrink: 0; display: block; }
  .et-info { display: flex; flex-direction: column; gap: .4mm; min-width: 0; overflow: hidden; }
  .et-club { display: flex; align-items: center; gap: 1mm; font-size: 6pt; font-weight: 700; color: #15803d; }
  .et-club img { height: 4mm; width: auto; object-fit: contain; }
  .et-code { font-family: monospace; font-size: 8.5pt; font-weight: 800; color: #0f172a; line-height: 1.1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .et-gen { font-size: 7.5pt; font-weight: 600; color: #15803d; line-height: 1.15; }
  .et-meta { font-size: 6.5pt; color: #475569; line-height: 1.2; }
`
