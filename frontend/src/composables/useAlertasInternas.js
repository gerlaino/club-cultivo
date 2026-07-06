import { ref, computed, onMounted, onUnmounted } from 'vue'
import { createConsumer } from '@rails/actioncable'
import { cableUrl } from '../lib/cable.js'
import { getAlertasInternas, marcarAlertaInterna, marcarTodasAlertasLeidas } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'

// Fallback poll interval — WebSocket handles real-time; poll catches missed events
const POLL_MS = 5 * 60_000

// Singleton shared state — null means "not yet loaded"
const alertas  = ref(null)
const noLeidas = computed(() => (alertas.value ?? []).filter(a => !a.leida))
// Total real de no leídas (del meta del backend): puede ser mayor que las cargadas (limite=20).
// Es la fuente del badge de la campana. Se mantiene vivo ante WS / marcar leídas.
const metaNoLeidas = ref(0)
const count    = computed(() => metaNoLeidas.value || noLeidas.value.length)

let instanceCount = 0
let intervalId    = null
let consumer      = null

async function refresh() {
  if (document.hidden) return
  try {
    const res = await getAlertasInternas({ solo_no_leidas: 1, limite: 20 })
    alertas.value = res.data.data ?? []
    metaNoLeidas.value = res.data.meta?.no_leidas ?? alertas.value.filter(a => !a.leida).length
  } catch {
    // Silently ignore during auth transitions; default to empty so UI isn't stuck on skeletons
    if (alertas.value === null) alertas.value = []
  }
}

function onVisibility() {
  if (!document.hidden) refresh()
}

function conectarWS() {
  if (consumer) return
  try {
    consumer = createConsumer(cableUrl())
    consumer.subscriptions.create('AlertasInternasChannel', {
      received(data) {
        const current = alertas.value ?? []
        if (!current.find(a => a.id === data.id)) {
          alertas.value = [{ ...data, leida: false }, ...current].slice(0, 50)
          metaNoLeidas.value += 1
        }
      },
    })
  } catch (e) {
    console.warn('[useAlertasInternas] WebSocket no disponible, usando polling', e.message)
  }
}

function desconectarWS() {
  if (!consumer) return
  consumer.disconnect()
  consumer = null
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

export function useAlertasInternas() {
  const auth = useAuthStore()

  onMounted(() => {
    instanceCount++
    if (instanceCount === 1 && auth.isAuthenticated) {
      startPolling()
      conectarWS()
    }
  })

  onUnmounted(() => {
    instanceCount--
    if (instanceCount === 0) {
      stopPolling()
      desconectarWS()
      alertas.value = null
    }
  })

  async function marcarLeida(id) {
    const idx = alertas.value.findIndex(a => a.id === id)
    const eraNoLeida = idx !== -1 && !alertas.value[idx].leida
    await marcarAlertaInterna(id)
    if (idx !== -1) alertas.value[idx] = { ...alertas.value[idx], leida: true }
    if (eraNoLeida) metaNoLeidas.value = Math.max(0, metaNoLeidas.value - 1)
  }

  async function marcarTodas() {
    await marcarTodasAlertasLeidas()
    alertas.value = alertas.value.map(a => ({ ...a, leida: true }))
    metaNoLeidas.value = 0
  }

  return { alertas, noLeidas, count, metaNoLeidas, refresh, marcarLeida, marcarTodas }
}
