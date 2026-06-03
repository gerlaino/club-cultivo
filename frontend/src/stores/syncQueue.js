import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

const STORAGE_KEY = 'cc_sync_queue'

function load() {
  try { return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]') } catch { return [] }
}
function persist(items) {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(items)) } catch {}
}

export const useSyncQueueStore = defineStore('syncQueue', () => {
  const items = ref(load())

  const pendientes = computed(() => items.value.filter(i => i.status === 'pendiente'))
  const fallidos   = computed(() => items.value.filter(i => i.status === 'fallido'))
  const total      = computed(() => pendientes.value.length + fallidos.value.length)

  function encolar(tipo, { url, method = 'POST', payload }) {
    const item = {
      id:        crypto.randomUUID(),
      tipo,
      url,
      method,
      payload,
      timestamp: new Date().toISOString(),
      attempts:  0,
      status:    'pendiente',
    }
    items.value.push(item)
    persist(items.value)
    return item
  }

  function marcarEnviado(id) {
    items.value = items.value.filter(i => i.id !== id)
    persist(items.value)
  }

  function marcarFallido(id) {
    const item = items.value.find(i => i.id === id)
    if (item) { item.status = 'fallido'; item.attempts++ }
    persist(items.value)
  }

  function reintentarFallidos() {
    items.value.forEach(i => { if (i.status === 'fallido') i.status = 'pendiente' })
    persist(items.value)
  }

  function eliminar(id) {
    items.value = items.value.filter(i => i.id !== id)
    persist(items.value)
  }

  return {
    items, pendientes, fallidos, total,
    encolar, marcarEnviado, marcarFallido, reintentarFallidos, eliminar,
  }
})
