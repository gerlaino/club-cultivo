import { onMounted, onUnmounted } from 'vue'
import { createConsumer } from '@rails/actioncable'
import { cableUrl } from '../lib/cable.js'

let consumer      = null
let instanceCount = 0

// `onEvento` recibe TODOS los mensajes del canal, no sólo los de stock. Se agregó para el
// mostrador: la mesa cambia cuando el admin baja producto desde su oficina, y sin esto el que
// atiende no se enteraba hasta recargar — con el paquete ya sobre el mostrador.
//
// Se reusa este canal en vez de abrir otro: es el mismo club y la misma conexión, y una segunda
// suscripción sobre el mismo consumer singleton es una fuente de fugas.
export function useStockChannel(onStockActualizado, onEvento = null) {
  onMounted(() => {
    instanceCount++
    if (instanceCount > 1) return
    try {
      consumer = createConsumer(cableUrl())
      consumer.subscriptions.create('StocksChannel', {
        received(data) {
          if (data.tipo === 'stock_actualizado') onStockActualizado?.(data)
          onEvento?.(data)
        },
      })
    } catch (e) {
      console.warn('[useStockChannel] WebSocket no disponible', e.message)
    }
  })

  onUnmounted(() => {
    instanceCount--
    if (instanceCount === 0 && consumer) {
      consumer.disconnect()
      consumer = null
    }
  })
}
