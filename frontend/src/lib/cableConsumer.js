// UN solo WebSocket para toda la app.
//
// Cada composable abría su propio `createConsumer` (alertas, stock, ambiente): tres conexiones
// por pestaña que el navegador negocia por separado y que en el teléfono cuestan batería. Acá
// hay una, se abre la primera vez que alguien la pide y se cierra al cerrar sesión.
import { createConsumer } from '@rails/actioncable'
import { cableUrl } from './cable.js'

let consumer = null

export function consumidorCable() {
  if (!consumer) consumer = createConsumer(cableUrl())
  return consumer
}

export function cerrarCable() {
  if (!consumer) return
  try { consumer.disconnect() } catch {}
  consumer = null
}
