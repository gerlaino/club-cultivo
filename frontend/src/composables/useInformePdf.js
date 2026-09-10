import { ref } from 'vue'
import { descargarArchivo } from '../lib/descargas.js'
import { useToast } from './useToast.js'
import { hoyISO } from '../utils/dates.js'

// Descarga de informes en PDF y Excel.
//
// Antes esto capturaba la pantalla con html2canvas: el "PDF" era una foto JPEG de la página
// web. Sin texto seleccionable ni buscable, con la calidad atada al zoom del navegador, las
// columnas cortadas donde cayeran y sin membrete. Un informe que se presenta ante un auditor
// no puede ser una captura de pantalla.
//
// Ahora los genera el servidor (Prawn para el PDF, caxlsx para el Excel) a partir de la misma
// definición que alimenta la pantalla, así los tres formatos dicen exactamente lo mismo.
export function useInformePdf(nombre, recurso = null) {
  const hoja      = ref(null)   // se mantiene por compatibilidad con las vistas existentes
  const exporting = ref(false)
  const toast     = useToast()

  // `recurso` es el path del informe (ej. 'dispensaciones'); si no viene se deduce del nombre
  // del archivo, que sigue el patrón informe_<recurso>.
  const path = recurso || nombre.replace(/^informe_/, '')

  async function descargar(formato, params = {}) {
    exporting.value = true
    try {
      await descargarArchivo(`/informes/${path}.${formato}`, {
        params,
        filename: `${nombre}_${hoyISO()}.${formato}`,
      })
    } catch (e) {
      // El motivo lo lee `descargarArchivo`: acá sólo se decide cuánto dejarlo en pantalla.
      // Un rechazo con explicación (faltan variedades por declarar) no se lee en 5 segundos.
      toast.error(e.message, { timeout: e.conMotivo ? 9000 : 5000 })
    } finally {
      exporting.value = false
    }
  }

  const exportarPdf  = (params = {}) => descargar('pdf', params)
  const exportarXlsx = (params = {}) => descargar('xlsx', params)

  return { hoja, exporting, exportarPdf, exportarXlsx, descargar }
}
