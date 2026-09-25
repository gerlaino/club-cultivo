import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

// Bug real (Germán, pantalla Lotes): «target must be an object». El refresco por cable volvía a
// pedir los lotes de cada sala con la clave guardada como texto ("12"); `listLotes("12")` lo
// tomaba como filtros y axios reventaba. Se prueba contra el api real, con la red simulada.
const get = vi.fn()
vi.mock('axios', () => {
  const instance = {
    get: (...a) => get(...a),
    post: vi.fn(), put: vi.fn(), patch: vi.fn(), delete: vi.fn(),
    interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } },
    defaults: { headers: { common: {} } },
  }
  return { default: { create: () => instance, ...instance } }
})

describe('lotes: refresco de las salas ya cargadas', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    get.mockReset()
    get.mockResolvedValue({ data: [] })
  })

  it('pide los lotes de la sala por su ruta aunque la clave quedó como texto', async () => {
    const { useLotesStore } = await import('../stores/lotes.js')
    const store = useLotesStore()
    await store.fetchBySala(12)
    get.mockClear()

    await store.refrescar()

    expect(get).toHaveBeenCalledWith('/salas/12/lotes')
  })

  it('un refresco silencioso que falla no deja error en la pantalla de Lotes', async () => {
    const { useLotesStore } = await import('../stores/lotes.js')
    const store = useLotesStore()
    get.mockResolvedValueOnce({ data: [{ id: 1, codigo: 'L-1' }] })
    await store.fetch()
    get.mockRejectedValue(new Error('se cortó'))

    await store.refrescar()

    expect(get).toHaveBeenLastCalledWith('/lotes', { params: undefined })
    expect(store.error).toBeNull()
    expect(store.items).toHaveLength(1)
  })

  it('la carga normal sí muestra el error', async () => {
    const { useLotesStore } = await import('../stores/lotes.js')
    const store = useLotesStore()
    get.mockRejectedValue(new Error('se cortó'))

    await store.fetch()

    expect(store.error).toBe('se cortó')
  })
})
