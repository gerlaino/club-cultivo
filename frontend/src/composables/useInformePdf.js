import { ref } from 'vue'

// Descarga de informes a PDF (auditor). Cada vista bindea `hoja` a su contenido
// (ref="hoja") y llama exportarPdf() desde un botón. html2pdf se importa lazy.
export function useInformePdf(nombre) {
  const hoja      = ref(null)
  const exporting = ref(false)

  async function exportarPdf() {
    if (!hoja.value) return
    exporting.value = true
    try {
      const html2pdf = (await import('html2pdf.js')).default
      await html2pdf().set({
        margin:      8,
        filename:    `${nombre}_${new Date().toISOString().slice(0, 10)}.pdf`,
        image:       { type: 'jpeg', quality: 0.95 },
        html2canvas: { scale: 2, useCORS: true },
        jsPDF:       { unit: 'mm', format: 'a4', orientation: 'landscape' },
      }).from(hoja.value).save()
    } finally {
      exporting.value = false
    }
  }

  return { hoja, exporting, exportarPdf }
}
