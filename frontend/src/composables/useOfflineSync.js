import { ref, watch } from 'vue'
import { useNetwork } from './useNetwork.js'
import { useSyncQueueStore } from '../stores/syncQueue.js'
import { useToast } from './useToast.js'
import api from '../lib/api.js'

const syncing = ref(false)

export function useOfflineSync() {
  const { isOnline } = useNetwork()
  const toast        = useToast()

  async function procesarCola() {
    const queue = useSyncQueueStore()
    if (syncing.value || !isOnline.value) return
    const pendientes = [...queue.pendientes]
    if (!pendientes.length) return

    syncing.value = true
    let ok = 0, fail = 0

    for (const item of pendientes) {
      try {
        await api.request({ method: item.method, url: item.url, data: item.payload })
        queue.marcarEnviado(item.id)
        ok++
      } catch (e) {
        // Error de red → mantener para el próximo intento
        if (!e.response) break
        // Error de validación → no tiene caso reintentar, marcar fallido
        queue.marcarFallido(item.id)
        fail++
      }
    }

    syncing.value = false

    if (ok > 0) toast.success(`${ok} ${ok === 1 ? 'registro sincronizado' : 'registros sincronizados'} ✓`)
    if (fail > 0) toast.warning(`${fail} ${fail === 1 ? 'registro no pudo sincronizarse' : 'registros no pudieron sincronizarse'} — revisá la cola`)
  }

  // Trigger automático al volver online
  watch(isOnline, (online) => {
    if (online) setTimeout(procesarCola, 1500) // delay para que la conexión estabilice
  })

  return { syncing, isOnline, procesarCola }
}
