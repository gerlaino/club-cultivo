import { ref, computed } from 'vue'
import { useQRCode } from './useQRCode.js'
import { grillaDe, A4 } from '../lib/pdfEtiquetas.js'

/**
 * Etiquetas QR en tanda (plantas o lotes) → **PDF**, con progreso y bloqueo de pantalla.
 *
 * Tres cosas que no son obvias:
 *
 * 1. **PDF y no HTML.** En una hoja HTML los milímetros son una sugerencia: el diálogo de impresión
 *    aplica su "ajustar a la página" y encoge todo un 3-5%. En el PDF la geometría queda clavada.
 *    jsPDF se importa lazy, así que no pesa en el bundle de las demás rutas.
 * 2. **La ventana de impresión se abre ANTES de generar.** `window.open()` después de un `await` ya
 *    no cuenta como gesto del usuario y el bloqueador de popups la mata. Se abre en el click con un
 *    cartel de "generando" y recién al final recibe el PDF; por eso el config puede venir como
 *    FUNCIÓN (resolverlo antes —traer el club, el logo— ya gastaría el gesto).
 * 3. **Mientras genera, `ocupado` = true** y la vista tapa todo con BloqueoProgreso: no se puede
 *    cambiar el filtro ni volver a disparar la tanda a mitad de camino.
 * 4. **El PDF se ordena solo** (`ordenPor`), sin importar cómo esté ordenada la tabla — ver abajo.
 */

// El orden de la plancha NO es el de la tabla. La tabla ordena por fecha de creación, y eso parte
// un lote ampliado más tarde en dos bloques lejanos: si cargaste 3 plantas y 20 minutos después le
// sumaste 9, las P001-P003 caen decenas de etiquetas más abajo, entre plantas de otros lotes. Se
// etiqueta recorriendo el lote, no la línea de tiempo del alta: un lote, todas sus plantas en orden,
// después el siguiente.
//
// `numeric: true` es lo que hace que P002 vaya antes que P010; un localeCompare pelado ordena por
// caracter y pone P10 antes que P2 en cuanto el número deje de tener padding.
const COLLATOR = new Intl.Collator('es', { numeric: true, sensitivity: 'base' })

/** Ordena una copia por la clave compuesta que devuelve `ordenPor` (ej: [lote, nombre]). */
function ordenarItems(items, ordenPor) {
  if (typeof ordenPor !== 'function') return items
  return [...items].sort((a, b) => {
    const ka = ordenPor(a) || [], kb = ordenPor(b) || []
    for (let i = 0; i < Math.max(ka.length, kb.length); i++) {
      const c = COLLATOR.compare(String(ka[i] ?? ''), String(kb[i] ?? ''))
      if (c !== 0) return c
    }
    return 0
  })
}

export function useEtiquetasQR() {
  const { generatePNG } = useQRCode()

  const ocupado = ref(false)
  const accion  = ref('')     // 'imprimir' | 'descargar'
  const hechas  = ref(0)
  const total   = ref(0)

  const titulo = computed(() =>
    accion.value === 'descargar' ? 'Generando el PDF…' : 'Generando etiquetas…')

  async function resolver(config) {
    return typeof config === 'function' ? await config() : config
  }

  /**
   * Arma el PDF etiqueta por etiqueta.
   * @param {Array}    items    ítems a etiquetar
   * @param {Function} urlDe    (item) => URL que codifica el QR
   * @param {Object}   layout   LAYOUT_LOTE | LAYOUT_PLANTA (medidas en mm)
   * @param {Function} dibujar  (doc, x, y, datos) => void
   * @param {Function} datosDe  (item, qrDataUrl) => datos para dibujar
   * @param {Function} [ordenPor] (item) => clave compuesta con la que se ordena la plancha
   */
  async function construirPdf({ items: sinOrdenar, urlDe, layout, dibujar, datosDe, ordenPor }) {
    const { jsPDF } = await import('jspdf')

    const items  = ordenarItems(sinOrdenar, ordenPor)
    hechas.value = 0
    total.value  = items.length

    const doc = new jsPDF({ unit: 'mm', format: 'a4', orientation: layout.orientacion })
    const pagina = A4[layout.orientacion]
    const { cols, porPagina } = grillaDe(layout, pagina)

    for (let i = 0; i < items.length; i++) {
      if (i > 0 && i % porPagina === 0) doc.addPage()

      const enPagina = i % porPagina
      const col = enPagina % cols
      const fila = Math.floor(enPagina / cols)
      const x = layout.margen + col * (layout.ancho + layout.gap)
      const y = layout.margen + fila * (layout.alto + layout.gap)

      // Las opciones del QR (corrección de error, zona muda, color) viven en el layout: cambian
      // según dónde va a vivir la pieza. Ver el comentario en pdfEtiquetas.js.
      const qr = await generatePNG(urlDe(items[i]), layout.qr)
      dibujar(doc, x, y, datosDe(items[i], qr))
      hechas.value++
    }

    return doc
  }

  const ESPERA_HTML = `<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
<title>Generando etiquetas…</title></head>
<body style="font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;
height:100vh;margin:0;color:#3A3F44">
<p>Generando etiquetas… no cierres esta ventana.</p></body></html>`

  async function imprimir(config) {
    if (ocupado.value) return { ok: false }
    ocupado.value = true
    accion.value  = 'imprimir'

    // Se abre YA, en el mismo tick del click, antes de cualquier await (ver punto 2).
    const win = window.open('', '_blank', 'width=900,height=1000')
    if (win) { win.document.write(ESPERA_HTML); win.document.close() }

    try {
      const cfg = await resolver(config)
      if (!cfg?.items?.length) { win?.close(); return { ok: false, vacio: true } }

      const doc = await construirPdf(cfg)
      doc.autoPrint()                       // el visor abre el diálogo de impresión solo
      const url = URL.createObjectURL(doc.output('blob'))

      if (!win) {
        // Popup bloqueado: no perdemos el trabajo, se baja el PDF.
        descargarBlob(url, `${cfg.archivo || 'etiquetas'}.pdf`)
        return { ok: true, viaDescarga: true }
      }
      win.location.href = url
      // La URL no se revoca al instante: el visor todavía la está leyendo.
      setTimeout(() => URL.revokeObjectURL(url), 60_000)
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

      const doc = await construirPdf(cfg)
      doc.save(`${cfg.archivo || 'etiquetas'}.pdf`)
      return { ok: true }
    } catch (e) {
      return { ok: false, error: e }
    } finally {
      ocupado.value = false
      accion.value  = ''
    }
  }

  function descargarBlob(url, filename) {
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    setTimeout(() => URL.revokeObjectURL(url), 10_000)
  }

  return { ocupado, accion, hechas, total, titulo, imprimir, descargar }
}
