import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (22-oct-2026, Germán): «hice un pedido para un usuario nuevo desde un club… está en consultas,
// pero no hay nada que me indique que tengo una consulta sin leer». La barra lateral dice cuántas
// hay sin atender; el Inicio lo pone primero, con su acción; sin pendientes no aparece nada.
let pendientes = 2
let pulso = { totales: { clubes_operando: 1 }, consultas_pendientes: 2 }
vi.mock('../lib/api.js', () => ({
  getConsultasPendientes: () => Promise.resolve({ data: { pendientes } }),
  getSuperAdminEstado:    () => Promise.resolve({ data: { estado: 'bien' } }),
  getSuperAdminPulso:     () => Promise.resolve({ data: pulso }),
}))
const push = vi.fn()
vi.mock('vue-router', () => ({
  useRouter: () => ({ push, replace: vi.fn() }),
  useRoute:  () => ({ name: 'sa-dashboard' }),
}))

const stubs = { RouterLink: { props: ['to'], template: '<a><slot /></a>' }, DsSpinner: true, DsAvatar: true }

describe('Consultas sin atender', () => {
  beforeEach(() => { setActivePinia(createPinia()); push.mockClear() })

  it('la barra lateral muestra cuántas hay', async () => {
    pendientes = 2
    const { default: Sidebar } = await import('../components/layout/SuperAdminSidebar.vue')
    const w = mount(Sidebar, { global: { stubs } })
    await flushPromises()
    const link = w.findAll('.sasb__link').find(l => l.text().includes('Consultas'))
    expect(link.find('.sasb__badge').text()).toBe('2')
  })

  it('sin pendientes, la barra no muestra número', async () => {
    pendientes = 0
    const { default: Sidebar } = await import('../components/layout/SuperAdminSidebar.vue')
    const w = mount(Sidebar, { global: { stubs } })
    await flushPromises()
    expect(w.find('.sasb__badge').exists()).toBe(false)
  })

  it('el Inicio las pone primero y lleva a la bandeja', async () => {
    pulso = { totales: { clubes_operando: 1 }, consultas_pendientes: 2 }
    const { default: SADashboard } = await import('../views/superadmin/SADashboard.vue')
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()
    const primero = w.find('.sad__grupo')
    expect(primero.text()).toContain('Te escribieron')
    expect(primero.text()).toContain('2 consultas sin atender')
    await primero.find('.sad__pend').trigger('click')
    expect(push).toHaveBeenCalledWith({ name: 'sa-consultas' })
  })

  it('el Inicio no la menciona si no hay ninguna', async () => {
    pulso = { totales: { clubes_operando: 1 }, consultas_pendientes: 0 }
    const { default: SADashboard } = await import('../views/superadmin/SADashboard.vue')
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()
    expect(w.text()).not.toContain('Te escribieron')
  })
})
