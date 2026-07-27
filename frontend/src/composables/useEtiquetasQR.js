import { ref, computed } from 'vue'
import { useQRCode } from './useQRCode.js'

/**
 * Impresión/descarga de etiquetas QR EN TANDA (plantas o lotes), con progreso y bloqueo de pantalla.
 *
 * Dos cosas que no son obvias y son la razón de que esto sea un composable y no código pegado en
 * cada vista:
 *
 * 1. La ventana de impresión se abre ANTES de generar. `window.open()` después de un `await` ya no
 *    cuenta como "gesto del usuario" y el bloqueador de popups la mata — que es lo que pasaba al
 *    imprimir las etiquetas de un lote. Se abre en el click, se le escribe un cartel de "generando"
 *    y recién al final se le mete el HTML definitivo.
 * 2. Mientras genera, `ocupado` queda en true y la vista tapa todo con BloqueoProgreso: no se puede
 *    cambiar el filtro ni volver a disparar la tanda a mitad de camino.
 */
export function useEtiquetasQR() {
  const { generatePNG } = useQRCode()

  const ocupado = ref(false)
  const accion  = ref('')     // 'imprimir' | 'descargar'
  const hechas  = ref(0)
  const total   = ref(0)

  const titulo = computed(() =>
    accion.value === 'descargar' ? 'Preparando la descarga…' : 'Generando etiquetas…')

  function esc(s) {
    return String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]))
  }

  /**
   * Genera el HTML de la hoja.
   * @param {Array}    items    ítems a etiquetar
   * @param {Function} urlDe    (item) => URL que codifica el QR
   * @param {Function} htmlDe   (item, qrDataUrl) => HTML de UNA etiqueta
   * @param {String}   css      CSS de la hoja (incluye @page y el layout)
   * @param {String}   nombre   título del documento
   * @param {Object}   qrOpts   opciones del QR
   */
  async function construirHoja({ items, urlDe, htmlDe, css, nombre, qrOpts = {} }) {
    hechas.value = 0
    total.value  = items.length

    const partes = []
    for (const item of items) {
      const qr = await generatePNG(urlDe(item), {
        width: 200, margin: 2, color: { dark: '#1b5e20', light: '#ffffff' }, ...qrOpts,
      })
      partes.push(htmlDe(item, qr))
      hechas.value++
    }

    return `<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><title>${esc(nombre)}</title>
<style>${css}</style></head>
<body><div class="hoja">${partes.join('')}</div></body></html>`
  }

  /** Cartel dentro de la ventana de impresión mientras se genera (se abre vacía y hay que decir algo). */
  const ESPERA_HTML = `<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
<title>Generando etiquetas…</title></head>
<body style="font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;
height:100vh;margin:0;color:#3A3F44">
<p>Generando etiquetas… no cierres esta ventana.</p></body></html>`

  /** Acepta el config o una FUNCIÓN que lo resuelve (puede ser async: traer el club, el logo, etc.). */
  async function resolver(config) {
    return typeof config === 'function' ? await config() : config
  }

  async function imprimir(config) {
    if (ocupado.value) return { ok: false }
    ocupado.value = true
    accion.value  = 'imprimir'

    // Se abre YA, en el mismo tick del click, ANTES de cualquier await (ver punto 1 del docstring).
    // Por eso el config se resuelve después: si se resolviera antes, el await de turno (fetch del
    // club, del logo) ya nos habría costado el gesto del usuario y el popup moriría.
    const win = window.open('', '_blank', 'width=900,height=1000')
    if (win) { win.document.write(ESPERA_HTML); win.document.close() }

    try {
      const cfg = await resolver(config)
      if (!cfg?.items?.length) { win?.close(); return { ok: false, vacio: true } }

      const html = await construirHoja(cfg)
      if (!win) {
        // Popup bloqueado: no perdemos el trabajo, se baja como archivo.
        bajarArchivo(html, `${cfg.archivo || 'etiquetas'}.html`)
        return { ok: true, viaDescarga: true }
      }
      win.document.open()
      win.document.write(html)
      win.document.close()
      win.focus()
      setTimeout(() => { try { win.print() } catch { /* la ventana quedó abierta: se imprime a mano */ } }, 500)
      return { ok: true }
    } catch (e) {
      win?.close()
      return { ok: false, error: e }
    } finally {
      ocupado.value = false
      accion.value  = ''
    }
  }

  async function descargar(config) {
    if (ocupado.value) return { ok: false }
    ocupado.value = true
    accion.value  = 'descargar'
    try {
      const cfg = await resolver(config)
      if (!cfg?.items?.length) return { ok: false, vacio: true }

      const html = await construirHoja(cfg)
      bajarArchivo(html, `${cfg.archivo || 'etiquetas'}.html`)
      return { ok: true }
    } catch (e) {
      return { ok: false, error: e }
    } finally {
      ocupado.value = false
      accion.value  = ''
    }
  }

  function bajarArchivo(html, filename) {
    const url = URL.createObjectURL(new Blob([html], { type: 'text/html;charset=utf-8' }))
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  return { ocupado, accion, hechas, total, titulo, imprimir, descargar, esc }
}
