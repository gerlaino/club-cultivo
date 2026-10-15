import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

// AC (Germán, 15-oct-2026): «a veces pasa eso cuando me deslogueo de super admin o me logueo con
// algún user… es un segundo y después labura bien» — el cartel «No tenés acceso a esa sección con tu
// rol (medico)». El ?redirect quedaba de la sesión anterior y el usuario nuevo era mandado ahí.
// La decisión de qué rol entra a qué ruta es la REAL del router (`puedeEntrar`), no una copia.
const mocks = vi.hoisted(() => ({ me: vi.fn(), signIn: vi.fn(), signOut: vi.fn(), clearAuthToken: vi.fn() }))
vi.mock('../lib/api', () => mocks)
const routerPush = vi.hoisted(() => vi.fn())
vi.mock('../stores/club.js', () => ({ useClubStore: () => ({ fetch: vi.fn(() => Promise.resolve()) }) }))
vi.mock('../composables/usePlan.js', () => ({ usePlan: () => ({ planData: { value: null } }) }))
vi.mock('../router', async () => {
  const { puedeEntrar } = await vi.importActual('../router/index.js')
  return { default: { push: routerPush }, puedeEntrar }
})

const { useAuthStore } = await import('../stores/auth')

async function entrarComo (role, redirect) {
  mocks.signIn.mockResolvedValue({})
  mocks.me.mockResolvedValue({ data: { id: 9, role } })
  await useAuthStore().login('x@y.com', 'clave', redirect)
  return routerPush.mock.calls.at(-1)[0]
}

describe('login: el destino guardado de la sesión anterior', () => {
  beforeEach(() => { setActivePinia(createPinia()); vi.clearAllMocks() })

  it('el médico que entra después del super admin va a su inicio, no a la pantalla del super admin', async () => {
    expect(await entrarComo('medico', '/super-admin/clubs/3')).toEqual({ path: '/medico' })
  })

  it('el médico tampoco va a una pantalla de administración que le quedó guardada', async () => {
    expect(await entrarComo('medico', '/contabilidad?tab=caja')).toEqual({ path: '/medico' })
  })

  it('un admin que entra después del super admin no pasa por la pantalla del super admin', async () => {
    expect(await entrarComo('admin', '/super-admin/estado')).toEqual({ name: 'dashboard' })
  })

  it('un destino que el rol SÍ puede ver se respeta (un QR, una ficha)', async () => {
    expect(await entrarComo('medico', '/medico/pacientes/12')).toBe('/medico/pacientes/12')
  })
})
