import { onMounted, onUnmounted, ref } from 'vue'
import { useAmbienteStore } from '../stores/ambiente.js'
import { useAuthStore } from '../stores/auth.js'

const POLL_INTERVAL = 60_000
const ROLES_CON_ALERTAS = new Set(['admin', 'cultivador'])

export function useAlertasBell() {
  const store    = useAmbienteStore()
  const auth     = useAuthStore()
  const intervalId = ref(null)

  async function refresh() {
    if (document.hidden) return
    if (!ROLES_CON_ALERTAS.has(auth.user?.role)) return
    await store.cargarAlertas()
  }

  function onVisibility() {
    if (!document.hidden) refresh()
  }

  onMounted(() => {
    refresh()
    intervalId.value = setInterval(refresh, POLL_INTERVAL)
    document.addEventListener('visibilitychange', onVisibility)
  })

  onUnmounted(() => {
    clearInterval(intervalId.value)
    document.removeEventListener('visibilitychange', onVisibility)
  })

  return {
    count:   store.alertasCount,
    alertas: store.alertasActivas,
    refresh,
  }
}
