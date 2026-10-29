import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, RouterLinkStub } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// EL PACIENTE TIENE CÓMO SALIR (29-oct-2026, Germán: «no tengo manera de cerrar sesión siendo un
// paciente»). La salida estaba dentro del menú de tres rayas y al pie de páginas largas.
//
// AC:
//   - Arriba, en el teléfono, un ícono lleva a «Mi cuenta» sin abrir el menú.
//   - «Mi cuenta» tiene «Cerrar sesión», y cierra la sesión.
//   - «Mi cuenta» dice por dónde entra (su puerta, con DNI) y no muestra el usuario interno.

const logOut = vi.hoisted(() => vi.fn())
vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ user: { role: 'paciente', email: 'ana@club-modelo.paciente' }, logOut }),
}))
vi.mock('vue-router', async (orig) => ({ ...(await orig()), useRouter: () => ({ push: vi.fn() }) }))
vi.mock('@/lib/portalApi', () => ({ getPortalClub: vi.fn(), getPortalCuentaCorriente: vi.fn(() => Promise.resolve({ habilitada: false })) }))
vi.mock('@/stores/portalChat', () => ({ usePortalChatStore: () => ({ sinLeer: 0, cargar: vi.fn(), iniciar: vi.fn() }) }))

beforeEach(async () => {
  setActivePinia(createPinia())
  logOut.mockReset()
  const { usePortalClubStore } = await import('@/stores/portalClub')
  usePortalClubStore().club = { name: 'Club Modelo', slug: 'club_modelo' }
})

describe('Mi cuenta del paciente', () => {
  it('tiene «Cerrar sesión» y cierra la sesión', async () => {
    const { default: V } = await import('../views/portal/PortalCuentaView.vue')
    const w = mount(V)
    await w.get('[data-testid="cuenta-salir"]').trigger('click')
    expect(logOut).toHaveBeenCalledTimes(1)
  })

  it('dice por dónde entra y no muestra el usuario interno', async () => {
    const { default: V } = await import('../views/portal/PortalCuentaView.vue')
    const w = mount(V)
    expect(w.get('[data-testid="cuenta-puerta"]').text()).toContain('/paciente/club_modelo')
    expect(w.get('[data-testid="cuenta-puerta"]').text()).toContain('DNI')
    expect(w.text()).not.toContain('club-modelo.paciente')
  })

  it('arriba hay un acceso directo a «Mi cuenta», fuera del menú', async () => {
    const { default: N } = await import('../components/portal/PortalNavBar.vue')
    const w = mount(N, { global: { stubs: { RouterLink: RouterLinkStub } } })
    const link = w.get('[data-testid="portal-mi-cuenta"]')
    expect(link.findComponent(RouterLinkStub).props('to')).toBe('/portal/cuenta')
    expect(w.find('.pnb__movil').exists()).toBe(false) // el menú cerrado: el acceso no depende de abrirlo
  })
})
