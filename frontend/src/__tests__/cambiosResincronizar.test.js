// AC (Javi, 15-oct-2026): «devolví el pesaje y no actualizó en manicura». En el teléfono, con la
// pantalla apagada o la app atrás, el WebSocket se corta y los avisos de ese rato se pierden. Al
// reconectar, o al volver a la app, toda pantalla abierta tiene que re-pedir lo suyo.
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

let callbacks = null
vi.mock('../lib/cableConsumer.js', () => ({
  consumidorCable: () => ({ subscriptions: { create: (_canal, cb) => { callbacks = cb; return { unsubscribe() {} } } } }),
}))

const { alCambiar, alCambiarAgrupado, olvidarCambios } = await import('../lib/cambios.js')

function ocultar(estado) {
  Object.defineProperty(document, 'visibilityState', { value: estado, configurable: true })
  document.dispatchEvent(new Event('visibilitychange'))
}

describe('cambios: lo que pasó mientras no escuchaba', () => {
  beforeEach(() => { vi.useFakeTimers(); olvidarCambios(); callbacks = null })
  afterEach(() => { olvidarCambios(); vi.useRealTimers(); ocultar('visible') })

  it('al reconectarse el cable, cada pantalla abierta re-pide lo suyo (aunque su filtro no lo dejaría)', async () => {
    const lote = vi.fn(), pesajes = vi.fn()
    alCambiarAgrupado('lotes', lote, { filtro: ev => ev.id === 99 })
    alCambiarAgrupado('pesajes', pesajes)

    callbacks.connected()                // primera conexión: recién cargó, no re-pide
    await vi.runAllTimersAsync()
    expect(pesajes).not.toHaveBeenCalled()

    callbacks.disconnected?.()
    callbacks.connected()                // volvió después de un corte
    await vi.runAllTimersAsync()
    expect(pesajes).toHaveBeenCalledTimes(1)
    expect(lote).toHaveBeenCalledTimes(1)
  })

  it('al volver a la app después de un rato re-pide; un parpadeo de un segundo, no', async () => {
    const recargar = vi.fn()
    alCambiarAgrupado('pesajes', recargar)

    ocultar('hidden'); vi.advanceTimersByTime(1000); ocultar('visible')
    await vi.runAllTimersAsync()
    expect(recargar).not.toHaveBeenCalled()

    ocultar('hidden'); vi.advanceTimersByTime(60_000); ocultar('visible')
    await vi.runAllTimersAsync()
    expect(recargar).toHaveBeenCalledTimes(1)
  })

  it('una pantalla que ya se cerró no se re-pide, y los avisos sueltos (cambio de rol) no se disparan', async () => {
    const cerrada = vi.fn(), rol = vi.fn()
    const soltar = alCambiarAgrupado('pesajes', cerrada)
    alCambiar('usuarios', rol)
    soltar()

    callbacks.connected(); callbacks.connected()
    await vi.runAllTimersAsync()
    expect(cerrada).not.toHaveBeenCalled()
    expect(rol).not.toHaveBeenCalled()
  })

  it('un aviso normal sigue funcionando igual', async () => {
    const recargar = vi.fn()
    alCambiarAgrupado('pesajes', recargar)
    callbacks.received({ recurso: 'pesajes', accion: 'actualizado', id: 1 })
    await vi.runAllTimersAsync()
    expect(recargar).toHaveBeenCalledTimes(1)
  })
})
