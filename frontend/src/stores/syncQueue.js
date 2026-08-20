import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

const STORAGE_KEY = 'cc_sync_queue'

/**
 * NO HAY TTL, y sacarlo fue un arreglo, no un descuido.
 *
 * Había uno de 48 h "para evitar acumulación de entradas huérfanas". El problema es que entradas
 * huérfanas no existen: `marcarEnviado` BORRA el item, así que todo lo que sobrevive acá está
 * `pendiente` o `fallido` — o sea, trabajo real que todavía no llegó al servidor. El TTL sólo podía
 * borrar eso, y lo borraba **en silencio**, reescribiendo el localStorage al cargar.
 *
 * El caso concreto: la manicura pesa un viernes a la tarde en un galpón sin señal y no vuelve a
 * abrir la app hasta el lunes. El pesaje desaparecía y nadie se enteraba — justo lo que la cola
 * venía a proteger.
 *
 * Se descarta sólo por dos vías, las dos deliberadas: el servidor lo confirma, o alguien lo elimina
 * a mano.
 */
function load() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]')
  } catch { return [] }
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
