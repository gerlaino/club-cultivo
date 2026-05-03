import { ref, onMounted, onUnmounted, isRef } from 'vue'
import { useAmbienteStore } from '../stores/ambiente.js'

const POLL_INTERVAL = 30_000

export function useAmbiente(salaId, reactiveParams = {}) {
  const store = useAmbienteStore()
  const intervalId = ref(null)

  function refrescar() {
    if (document.hidden) return
    const id     = typeof salaId === 'function' ? salaId() : (isRef(salaId) ? salaId.value : salaId)
    const params = isRef(reactiveParams) ? reactiveParams.value : reactiveParams
    if (!id) return
    store.cargarAmbiente(id, params)
    store.cargarAlertas(id)
  }

  function onVisibility() {
    if (!document.hidden) refrescar()
  }

  onMounted(() => {
    refrescar()
    intervalId.value = setInterval(refrescar, POLL_INTERVAL)
    document.addEventListener('visibilitychange', onVisibility)
  })

  onUnmounted(() => {
    clearInterval(intervalId.value)
    document.removeEventListener('visibilitychange', onVisibility)
  })

  return { store, refrescar }
}
