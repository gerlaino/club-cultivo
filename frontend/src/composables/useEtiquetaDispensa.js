import { useClubStore } from '../stores/club'
import { useToast } from './useToast.js'
import { useQRCode } from './useQRCode.js'

const FORMA_LBL = { flor_seca: 'Flor seca', flor: 'Flor', aceite: 'Aceite', hash: 'Hash', extracto: 'Extracto', comestible: 'Comestible' }
function esc(s) { return String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])) }
function fmtFecha(d) {
  if (!d) return ''
  const [y, m, day] = String(d).slice(0, 10).split('-')
  return `${day}/${m}/${y}`
}

// Imprime la etiqueta física de una dispensa: logo+nombre del club (discreto) + QR
// grande que apunta a /d/:token (pasaporte con gate por DNI).
export function useEtiquetaDispensa() {
  const club = useClubStore()
  const toast = useToast()
  const { generatePNG } = useQRCode()

  async function imprimirEtiqueta(d) {
    if (!d?.token) { toast.error('Esta dispensa no tiene etiqueta (es anterior a la función)'); return }
    try {
      const url   = `${window.location.origin}/d/${d.token}`
      const qr    = await generatePNG(url, { width: 240, margin: 1, color: { dark: '#0F2A1E', light: '#ffffff' } })
      const clubN = club.data?.name || 'Club Cultivo'
      const logo  = club.data?.logo_url || ''
      const fecha = fmtFecha(d.fecha_dispensacion)
      const esMulti = d.multi_stock && Array.isArray(d.items) && d.items.length > 1

      // Cuerpo de datos: una etiqueta por paquete. Multi-stock lista cada producto; single
      // muestra la genética grande como antes. El QR (token de la dispensa) es el mismo.
      let titulo, dataHtml
      if (esMulti) {
        titulo  = `${d.items.length} productos`
        const lineas = d.items.map(it => {
          const forma = FORMA_LBL[it.stock?.forma_producto] || it.stock?.forma_producto || ''
          const cant  = `${it.cantidad}${it.stock?.unidad || 'g'}`
          const gen   = it.genetica_nombre || it.stock?.genetica?.nombre || ''
          const lote  = it.lote_codigo || it.stock?.lote?.codigo || ''
          const meta  = [gen, lote].filter(Boolean).map(esc).join(' · ')
          return `<div class="lbl-item"><span class="lbl-item-q">${esc(cant)}</span> ${esc(forma)}${meta ? ` <span class="lbl-item-m">· ${meta}</span>` : ''}</div>`
        }).join('')
        dataHtml = `<div class="lbl-gen">${esc(titulo)}</div>
      <div class="lbl-items">${lineas}</div>
      <div class="lbl-meta">${esc(fecha)}</div>`
      } else {
        const gen   = d.genetica_nombre || d.stock?.genetica?.nombre || '—'
        const forma = FORMA_LBL[d.stock?.forma_producto] || d.stock?.forma_producto || ''
        const cant  = `${d.cantidad}${d.stock?.unidad || 'g'}`
        const lote  = d.stock?.lote?.codigo || d.lote_codigo || ''
        titulo = gen
        dataHtml = `<div class="lbl-gen">${esc(gen)}</div>
      <div class="lbl-meta">${esc(forma)} · ${esc(cant)}${lote ? ' · ' + esc(lote) : ''}</div>
      <div class="lbl-meta">${esc(fecha)}</div>`
      }

      const html = `<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
<title>Etiqueta ${esc(titulo)}</title>
<style>
  @page { margin: 8mm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, system-ui, sans-serif; color: #0F2A1E; }
  .lbl { width: 62mm; border: 0.4px solid #cbd5e1; border-radius: 3mm; padding: 4mm; display: flex; gap: 3.5mm; align-items: center; page-break-inside: avoid; }
  .lbl-qr { width: 26mm; height: 26mm; flex-shrink: 0; }
  .lbl-qr img { width: 100%; height: 100%; display: block; }
  .lbl-data { min-width: 0; flex: 1; }
  .lbl-club { display: flex; align-items: center; gap: 1.5mm; font-size: 7pt; color: #5a8a72; font-weight: 700; margin-bottom: 1mm; }
  .lbl-club img { width: 4mm; height: 4mm; border-radius: 1mm; object-fit: cover; }
  .lbl-gen { font-size: 11pt; font-weight: 800; line-height: 1.1; }
  .lbl-meta { font-size: 8pt; color: #3f6452; margin-top: .8mm; }
  .lbl-items { margin-top: 1mm; display: flex; flex-direction: column; gap: .6mm; }
  .lbl-item { font-size: 7.5pt; color: #0F2A1E; line-height: 1.15; }
  .lbl-item-q { font-weight: 800; }
  .lbl-item-m { color: #5a8a72; }
  .lbl-foot { font-size: 6.5pt; color: #94a3b8; margin-top: 1.5mm; }
</style></head><body>
  <div class="lbl">
    <div class="lbl-qr"><img src="${qr}" alt="QR"></div>
    <div class="lbl-data">
      <div class="lbl-club">${logo ? `<img src="${esc(logo)}">` : ''}${esc(clubN)}</div>
      ${dataHtml}
      <div class="lbl-foot">Escaneá para ver la trazabilidad</div>
    </div>
  </div>
  <script>window.onload=function(){setTimeout(function(){window.print()},250)}<\/script>
</body></html>`

      const win = window.open('', '_blank', 'width=480,height=360')
      if (!win) { toast.error('Permití ventanas emergentes para imprimir'); return }
      win.document.write(html)
      win.document.close()
    } catch {
      toast.error('No se pudo generar la etiqueta')
    }
  }

  return { imprimirEtiqueta }
}
