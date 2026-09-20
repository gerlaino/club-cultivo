import { onMounted, onUnmounted } from 'vue'
import { consumidorCable } from '../lib/cableConsumer.js'

// Los avisos del canal viejo de stock (`stock_actualizado`, `envio_actualizado`,
// `mostrador_actualizado`). Una sola suscripción por pestaña y un registro de handlers: antes
// sólo el PRIMER componente montado recibía (los demás quedaban sin callback), así que si el
// dashboard ya escuchaba, la pantalla de mostrador que se abría después no se enteraba de nada.
const handlers = new Set()
let subscription = null

function asegurar() {
  if (subscription) return
  try {
    subscription = consumidorCable().subscriptions.create('StocksChannel', {
      received(data) { for (const h of [...handlers]) { try { h(data) } catch {} } },
    })
  } catch (e) {
    console.warn('[useStockChannel] WebSocket no disponible', e.message)
  }
}

export function useStockChannel(onStockActualizado, onEvento = null) {
  const handler = (data) => {
    if (data.tipo === 'stock_actualizado') onStockActualizado?.(data)
    onEvento?.(data)
  }
  onMounted(() => { handlers.add(handler); asegurar() })
  onUnmounted(() => { handlers.delete(handler) })
}
