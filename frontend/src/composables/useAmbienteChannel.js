import { onMounted, onUnmounted } from 'vue'
import { createConsumer } from '@rails/actioncable'

function cableUrl() {
  const base = import.meta.env.VITE_API_URL || 'http://localhost:3001/api'
  const root = base.replace(/\/api$/, '')
  const ws   = root.replace(/^http/, 'ws')
  return `${ws}/cable` // httpOnly cookie se envía automáticamente en el upgrade WS
}

export function useAmbienteChannel(salaId, onLectura) {
  let consumer     = null
  let subscription = null

  onMounted(() => {
    try {
      consumer     = createConsumer(cableUrl())
      subscription = consumer.subscriptions.create(
        { channel: 'AmbienteChannel', sala_id: salaId },
        {
          received(data) {
            onLectura(data)
          },
        }
      )
    } catch (e) {
      console.warn('[useAmbienteChannel] WebSocket no disponible', e.message)
    }
  })

  onUnmounted(() => {
    subscription?.unsubscribe()
    consumer?.disconnect()
    consumer = null
  })
}
