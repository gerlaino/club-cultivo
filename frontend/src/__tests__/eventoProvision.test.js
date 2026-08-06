import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

vi.mock('../lib/api.js', () => ({
  listProvisiones:  vi.fn(() => Promise.resolve({ data: [] })),
  listEventoCostos: vi.fn(() => Promise.resolve({ data: [] })),
  listVendibles:    vi.fn(() => Promise.resolve({ data: [] })),
  createProvision:  vi.fn(),
  updateProvision:  vi.fn(),
  deleteProvision:  vi.fn(),
  reservarProvisiones: vi.fn(),
  cerrarProvision:  vi.fn(),
  createEventoCosto: vi.fn(),
  deleteEventoCosto: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

const EventoProvision = (await import('../views/bar/EventoProvision.vue')).default

// El síntoma reportado: al tocar "+ Agregar" en un evento nuevo, la pantalla se oscurece
// (el velo aparece) pero no se ve la caja del modal. Montar el componente y disparar el
// click es la única forma de distinguir "no se renderiza" de "se renderiza y el CSS lo tapa".
describe('EventoProvision — modal Agregar', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    document.body.innerHTML = ''
  })

  const montar = () => mount(EventoProvision, {
    props: { barId: 1, evId: 1, estado: 'planificado' },
    global: { stubs: { DsSpinner: true } },
    attachTo: document.body,
  })

  it('monta sin errores con el evento vacío', async () => {
    const errores = []
    const wrapper = montar()
    wrapper.vm.$.appContext.config.errorHandler = (e) => errores.push(e)
    await new Promise((r) => setTimeout(r, 0))

    expect(errores).toEqual([])
    expect(document.body.innerHTML).toContain('Qué necesito')
  })

  it('al tocar "+ Agregar" aparece la caja, no sólo el velo', async () => {
    const wrapper = montar()
    await new Promise((r) => setTimeout(r, 0))

    const btn = wrapper.findAll('button').find(b => b.text().includes('Agregar'))
    expect(btn, 'debería existir el botón + Agregar').toBeTruthy()
    await btn.trigger('click')
    await new Promise((r) => setTimeout(r, 0))

    // El velo solo no alcanza: lo que se reporta es que la caja no aparece.
    expect(document.body.innerHTML).toContain('¿Qué estás sumando?')
    expect(document.body.innerHTML).toContain('Mercadería')
    expect(document.body.innerHTML).toContain('Servicio contratado')
  })
})
