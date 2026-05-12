import { ref, computed, onMounted, onUnmounted } from 'vue'
import { getAlertasInternas, marcarAlertaInterna, marcarTodasAlertasLeidas } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'

const POLL_MS = 60_000

// Shared state — singleton across all consumers
const alertas    = ref([])
const noLeidas   = computed(() => alertas.value.filter(a => !a.leida))
const count      = computed(() => noLeidas.value.length)

let instanceCount = 0
let intervalId    = null

async function refresh() {
  if (document.hidden) return
  try {
    const res = await getAlertasInternas({ solo_no_leidas: 1, limite: 20 })
    alertas.value = res.data.data ?? []
  } catch {
    // silently ignore — avoid console noise during auth transitions
  }
}

function startPolling() {
  if (intervalId) return
  refresh()
  intervalId = setInterval(refresh, POLL_MS)
  document.addEventListener('visibilitychange', onVisibility)
}

function stopPolling() {
  clearInterval(intervalId)
  intervalId = null
  document.removeEventListener('visibilitychange', onVisibility)
}

function onVisibility() {
  if (!document.hidden) refresh()
}

export function useAlertasInternas() {
  const auth = useAuthStore()

  onMounted(() => {
    instanceCount++
    if (instanceCount === 1 && auth.isAuthenticated) startPolling()
  })

  onUnmounted(() => {
    instanceCount--
    if (instanceCount === 0) stopPolling()
  })

  async function marcarLeida(id) {
    await marcarAlertaInterna(id)
    const idx = alertas.value.findIndex(a => a.id === id)
    if (idx !== -1) alertas.value[idx] = { ...alertas.value[idx], leida: true }
  }

  async function marcarTodas() {
    await marcarTodasAlertasLeidas()
    alertas.value = alertas.value.map(a => ({ ...a, leida: true }))
  }

  return { alertas, noLeidas, count, refresh, marcarLeida, marcarTodas }
}
