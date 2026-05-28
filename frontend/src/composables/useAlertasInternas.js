import { ref, computed, onMounted, onUnmounted } from 'vue'
import { createConsumer } from '@rails/actioncable'
import { getAlertasInternas, marcarAlertaInterna, marcarTodasAlertasLeidas } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'

// Fallback poll interval — WebSocket handles real-time; poll catches missed events
const POLL_MS = 5 * 60_000

// Singleton shared state — null means "not yet loaded"
const alertas  = ref(null)
const noLeidas = computed(() => (alertas.value ?? []).filter(a => !a.leida))
const count    = computed(() => noLeidas.value.length)

let instanceCount = 0
let intervalId    = null
let consumer      = null

function cableUrl() {
  const base  = import.meta.env.VITE_API_URL || 'http://localhost:3001/api'
  const root  = base.replace(/\/api$/, '')
  const ws    = root.replace(/^http/, 'ws')
  const token = localStorage.getItem('jwt_token') || ''
  return `${ws}/cable?token=${encodeURIComponent(token)}`
}

async function refresh() {
  if (document.hidden) return
  try {
    const res = await getAlertasInternas({ solo_no_leidas: 1, limite: 20 })
    alertas.value = res.data.data ?? []
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
