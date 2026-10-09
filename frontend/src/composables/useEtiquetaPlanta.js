// LA BANDERITA DE UNA PLANTA (etiqueta con su QR, plegable sobre el tronco). Una sola pieza para la
// ficha de escritorio y la del teléfono: en autocultivo se imprime para el secado o el frasco
// cuando se cosecha una sola (9-oct-2026). El dibujo vive en `lib/pdfEtiquetas.js`, el mismo que la
// impresión en tanda; PDF del tamaño exacto de la tira para que el plegado caiga donde tiene que caer.
import { ref } from 'vue'
import { useQRCode } from './useQRCode'
import { useClubStore } from '../stores/club'
import { useToast } from './useToast.js'
import { LAYOUT_PLANTA, dibujarBanderitaPlanta } from '../lib/pdfEtiquetas.js'

export function qrPlantaUrl(codigoQr) {
  return `${window.location.origin}/p/${codigoQr}`
}

export function useEtiquetaPlanta() {
  const { generatePNG } = useQRCode()
  const club = useClubStore()
  const toast = useToast()
  const generando = ref(false)

  async function imprimir(p) {
    if (!p?.codigo_qr || generando.value) return
    generando.value = true
    try {
      if (!club.data) { try { await club.fetch() } catch { /* la organización es opcional en la etiqueta */ } }
      const { jsPDF } = await import('jspdf')
      const qr = await generatePNG(qrPlantaUrl(p.codigo_qr), LAYOUT_PLANTA.qr)
      const doc = new jsPDF({ unit: 'mm', format: [LAYOUT_PLANTA.ancho, LAYOUT_PLANTA.alto], orientation: 'landscape' })
      dibujarBanderitaPlanta(doc, 0, 0, {
        qrDataUrl: qr,
        nombre:    p.nombre || p.codigo_qr,
        genetica:  p.genetica?.nombre,
        // En autocultivo el lote no se nombra: la planta se reconoce por su nombre y su genética.
        lote:      club.data?.personal ? null : p.lote?.codigo,
        inicio:    p.lote?.start_date,
        clubName:  club.name,
      })
      doc.save(`etiqueta-${p.nombre || p.codigo_qr}.pdf`)
    } catch {
      toast.error('No se pudo generar la etiqueta')
    } finally {
      generando.value = false
    }
  }

  return { imprimir, generando }
}
