import { describe, it, expect, vi, afterEach } from 'vitest'
import { borrarCachesDeSesion } from '../lib/cachesSesion.js'

// AC (29-oct-2026): lo que guardó el service worker (respuestas de la API, imágenes) es de quien
// tenía la sesión; se borra al cambiar de persona. La cáscara de la app no se toca. Entrar no
// puede quedar colgado esperando al caché.
function conCaches(keys, { borrar = () => Promise.resolve(true) } = {}) {
  const borrados = []
  vi.stubGlobal('caches', {
    keys: () => Promise.resolve(keys),
    delete: (k) => { borrados.push(k); return borrar(k) },
  })
  return borrados
}

afterEach(() => { vi.unstubAllGlobals(); vi.useRealTimers() })

describe('borrar lo guardado de la sesión', () => {
  it('borra la API y las imágenes, conserva la cáscara', async () => {
    const borrados = conCaches(['api-cache', 'assets-cache', 'workbox-precache-v2-https://x/'])
    await borrarCachesDeSesion()
    expect(borrados.sort()).toEqual(['api-cache', 'assets-cache'])
  })

  it('si el caché no contesta, sigue a los 1,5 s', async () => {
    vi.useFakeTimers()
    conCaches(['api-cache'], { borrar: () => new Promise(() => {}) })
    let listo = false
    borrarCachesDeSesion().then(() => { listo = true })
    await vi.advanceTimersByTimeAsync(1600)
    expect(listo).toBe(true)
  })

  it('sin Cache Storage no falla', async () => {
    vi.stubGlobal('caches', undefined)
    await expect(borrarCachesDeSesion()).resolves.toBeUndefined()
  })
})
