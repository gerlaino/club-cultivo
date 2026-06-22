import { onMounted, onUnmounted } from 'vue'
import { createConsumer } from '@rails/actioncable'
import { cableUrl } from '../lib/cable.js'

let consumer      = null
let instanceCount = 0

export function useStockChannel(onStockActualizado) {
  onMounted(() => {
    instanceCount++
    if (instanceCount > 1) return
    try {
      consumer = createConsumer(cableUrl())
      consumer.subscriptions.create('StocksChannel', {
        received(data) {
          if (data.tipo === 'stock_actualizado') {
            onStockActualizado(data)
          }
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
