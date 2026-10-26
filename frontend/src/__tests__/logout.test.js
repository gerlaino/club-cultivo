import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

const mocks = vi.hoisted(() => ({
  me: vi.fn(),
  signIn: vi.fn(),
  signOut: vi.fn(() => Promise.resolve()),
  clearAuthToken: vi.fn(),
}))
vi.mock('../lib/api', () => mocks)
vi.mock('../stores/club.js', () => ({ useClubStore: () => ({ fetch: vi.fn() }) }))
vi.mock('../composables/usePlan.js', () => ({ usePlan: () => ({ planData: { value: null } }) }))
vi.mock('../router', () => ({ default: { push: vi.fn() }, puedeEntrar: () => true }))

const { useAuthStore } = await import('../stores/auth')

// AC (26-oct-2026): cerrar sesión no deja datos de la persona en el navegador, no le rompe la app
// al service worker, y en la web te deja en la portada (no en el login).
describe('cerrar sesión', () => {
  let borrados, replace

  function montar({ instalada }) {
    borrados = []
    replace = vi.fn()
    vi.stubGlobal('caches', {
      keys: () => Promise.resolve(['workbox-precache-v2-https://cultivoespacial.com/', 'api-cache', 'assets-cache']),
      delete: (k) => { borrados.push(k); return Promise.resolve(true) },
    })
    vi.stubGlobal('location', { replace })
    vi.stubGlobal('matchMedia', () => ({ matches: instalada }))
  }

  beforeEach(() => setActivePinia(createPinia()))
  afterEach(() => vi.unstubAllGlobals())

  it('borra lo de la sesión (API e imágenes) y conserva la cáscara de la app', async () => {
    montar({ instalada: false })
    await useAuthStore().logOut()

    expect(borrados).toEqual(expect.arrayContaining(['api-cache', 'assets-cache']))
    expect(borrados.some((k) => k.startsWith('workbox-precache'))).toBe(false)
  })

  it('en la web va a la portada', async () => {
    montar({ instalada: false })
    await useAuthStore().logOut()
    expect(replace.mock.calls[0][0]).toMatch(/^\/bienvenida\?/)
  })

  it('en la app instalada va al login', async () => {
    montar({ instalada: true })
    await useAuthStore().logOut()
    expect(replace.mock.calls[0][0]).toMatch(/^\/login\?/)
  })

  it('aunque el servidor falle, se limpia igual y sale', async () => {
    montar({ instalada: false })
    mocks.signOut.mockRejectedValueOnce(new Error('sin red'))
    await useAuthStore().logOut()
    expect(borrados).toContain('api-cache')
    expect(replace).toHaveBeenCalledTimes(1)
  })
})
