import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createRouter, createMemoryHistory } from 'vue-router'
import { createPinia, setActivePinia } from 'pinia'

// «ASISTIRÉ» (27-oct-2026, Germán: «en eventos en lugar de me anoto debería decir asistiré»).
// AC: en un evento próximo el paciente toca «Asistiré» y queda marcado; tocar de nuevo lo
// desmarca. En uno que ya pasó no se ofrece.

const api = vi.hoisted(() => ({ getPortalEvento: vi.fn(), asistirEvento: vi.fn(), noAsistirEvento: vi.fn() }))
vi.mock('@/lib/portalApi', () => ({
  getPortalEvento: (...a) => api.getPortalEvento(...a),
  asistirEvento: (...a) => api.asistirEvento(...a),
  noAsistirEvento: (...a) => api.noAsistirEvento(...a),
}))

const V = (await import('../views/portal/PortalEventoDetailView.vue')).default
const router = createRouter({ history: createMemoryHistory(), routes: [{ path: '/:p(.*)*', component: { template: '<div/>' } }] })
const enDias = (d) => new Date(Date.now() + d * 86400000).toISOString()

async function abrir(evento) {
  api.getPortalEvento.mockResolvedValue(evento)
  await router.push('/portal/eventos/5')
  const w = mount(V, { global: { plugins: [router] } })
  await flushPromises()
  return w
}

beforeEach(() => { setActivePinia(createPinia()); Object.values(api).forEach((f) => f.mockReset()) })

describe('Asistiré', () => {
  it('marca que va y, tocando de nuevo, lo desmarca', async () => {
    const w = await abrir({ id: 5, titulo: 'Taller', fecha_inicio: enDias(10), asistire: false })
    const btn = () => w.find('[data-testid="asistire"]')
    expect(btn().text()).toBe('Asistiré')

    api.asistirEvento.mockResolvedValue({ id: 5, asistire: true })
    await btn().trigger('click')
    await flushPromises()
    expect(api.asistirEvento).toHaveBeenCalledWith(5)
    expect(btn().text()).toBe('Asistiré ✓')

    api.noAsistirEvento.mockResolvedValue({ id: 5, asistire: false })
    await btn().trigger('click')
    await flushPromises()
    expect(api.noAsistirEvento).toHaveBeenCalledWith(5)
    expect(btn().text()).toBe('Asistiré')
  })

  it('en un evento que ya pasó no se ofrece', async () => {
    const w = await abrir({ id: 5, titulo: 'Viejo', fecha_inicio: enDias(-3), asistire: false })
    expect(w.find('[data-testid="asistire"]').exists()).toBe(false)
  })
})
