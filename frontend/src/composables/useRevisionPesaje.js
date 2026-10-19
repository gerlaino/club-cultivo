import { ref, onBeforeUnmount } from 'vue'
import { revisarPesajeManicura, soltarRevisionPesajeManicura } from '../lib/api.js'

// «En revisión por X» (16-oct-2026, Javi): al abrir «Confirmar», el pesaje queda a nombre de quien
// confirma y la manicura no lo puede reabrir ni borrar mientras arma los frascos. `tomar` devuelve
// el pesaje como está AHORA (con su `enviado_at`, la versión que se manda al confirmar) o lanza el
// error del backend (otro lo está revisando, o ya no está enviado). `soltar` al cerrar sin confirmar;
// salir de la pantalla también suelta. Si el teléfono se apaga, el backend lo libera a los 15 min.
export function useRevisionPesaje() {
  const tomado = ref(null)   // { lote_id, id, enviado_at }

  async function tomar(p) {
    const { data } = await revisarPesajeManicura(p.lote_id, p.id)
    tomado.value = { lote_id: p.lote_id, id: p.id, enviado_at: data?.enviado_at }
    return data
  }

  async function soltar() {
    const t = tomado.value
    tomado.value = null
    if (!t) return
    try { await soltarRevisionPesajeManicura(t.lote_id, t.id) } catch { /* se libera solo */ }
  }

  // Confirmado: el backend ya lo soltó.
  function olvidar() { tomado.value = null }

  const version = () => tomado.value?.enviado_at

  onBeforeUnmount(soltar)
  return { tomar, soltar, olvidar, version }
}
