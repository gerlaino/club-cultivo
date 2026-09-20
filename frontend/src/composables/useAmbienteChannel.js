import { onMounted, onUnmounted } from 'vue'
import { consumidorCable } from '../lib/cableConsumer.js'

export function useAmbienteChannel(salaId, onLectura) {
  let subscription = null

  onMounted(() => {
    try {
      subscription = consumidorCable().subscriptions.create(
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
  })
}
