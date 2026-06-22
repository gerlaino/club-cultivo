import { onMounted, onUnmounted } from 'vue'
import { createConsumer } from '@rails/actioncable'
import { cableUrl } from '../lib/cable.js'

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
