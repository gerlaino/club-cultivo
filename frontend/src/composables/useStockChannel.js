import { onMounted, onUnmounted } from 'vue'
import { createConsumer } from '@rails/actioncable'

function cableUrl() {
  const base  = import.meta.env.VITE_API_URL || 'http://localhost:3001/api'
  const root  = base.replace(/\/api$/, '')
  const ws    = root.replace(/^http/, 'ws')
  const token = localStorage.getItem('jwt_token') || ''
  return `${ws}/cable?token=${encodeURIComponent(token)}`
}

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
