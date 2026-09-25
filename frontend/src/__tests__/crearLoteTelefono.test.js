import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { h } from 'vue'

// CREAR UN LOTE DESDE EL TELÉFONO (Germán, 23-sep-2026, uso personal): «quise crear un lote ya
// existente pero no tengo la opción».
//
// Y el alta de uno nuevo tampoco andaba: mandaba el estado `semilla`, que no existe, y el backend
// contestaba siempre «Estado no está en la lista». AC:
//   · un lote NUEVO nace enraizando, con su origen (semilla/esqueje) y al menos una planta;
//   · uno que YA EXISTÍA se carga con la fase en que está —sólo las que ese espacio admite— y los
//     días que lleva en cada fase (el backend calcula desde cuándo);
//   · en un espacio de floración un lote no nace: sólo se ofrece «ya lo tenía».
const api = vi.hoisted(() => ({
  getSala: vi.fn(), createLote: vi.fn(), createLoteHeredado: vi.fn(),
}))
vi.mock('../lib/api', () => ({
  getSala: (...a) => api.getSala(...a),
  listLotesDeSala: vi.fn(() => Promise.resolve({ data: [] })),
  listGeneticas: vi.fn(() => Promise.resolve({ data: [] })),
  listFotosSala: vi.fn(() => Promise.resolve({ data: [] })),
  createLote: (...a) => api.createLote(...a),
  createLoteHeredado: (...a) => api.createLoteHeredado(...a),
  createSalaNota: vi.fn(), uploadFotoSala: vi.fn(), updateSala: vi.fn(), cambiarFaseSala: vi.fn(),
}))
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: '99' }, query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn(), back: vi.fn() }),
  RouterLink: { render: () => null },
}))
vi.mock('../composables/useToast', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))
vi.mock('../stores/auth', () => ({
  useAuthStore: () => ({ user: { role: 'admin', reglas_cultivo: { kinds_sala_por_estado: {
    enraizado: ['vegetativo', 'mixta'], vegetativo: ['vegetativo', 'mixta'], floracion: ['floracion', 'mixta'],
  } } } }),
}))

// La hoja de abajo, sin animación ni Teleport: muestra su contenido cuando está abierta.
const SheetBottom = { props: ['modelValue', 'title'], setup: (p, { slots }) => () => (p.modelValue ? h('div', slots.default?.()) : null) }

async function montar (kind = 'vegetativo') {
  api.getSala.mockResolvedValue({ data: { id: 99, nombre: 'Carpa', kind } })
  api.createLote.mockResolvedValue({ data: { id: 1, estado: 'enraizado' } })
  api.createLoteHeredado.mockResolvedValue({ data: { id: 2, estado: 'vegetativo' } })
  setActivePinia(createPinia())
  const V = (await import('../views/mobile/MSalaMobileDetail.vue')).default
  const w = mount(V, { global: { stubs: { SheetBottom, RegistroSalaModal: true, RouterLink: true }, directives: { modal: {} } } })
  await flushPromises()
  w.vm.abrirNuevoLote()
  await flushPromises()
  return w
}

const crear = w => w.find('.msal__btn-confirmar').trigger('click')

describe('Teléfono › crear lote', () => {
  beforeEach(() => vi.clearAllMocks())

  it('uno nuevo nace enraizando, con su origen y sus plantas', async () => {
    const w = await montar()
    await w.find('#msal-plantas').setValue(4)
    await crear(w); await flushPromises()

    const [salaId, payload] = api.createLote.mock.calls[0]
    expect(salaId).toBe(99)
    expect(payload).toEqual(expect.objectContaining({ estado: 'enraizado', origen: 'semilla', plants_count: 4 }))
  })

  it('sin plantas no se manda', async () => {
    const w = await montar()
    await w.find('#msal-plantas').setValue(0)
    await crear(w); await flushPromises()

    expect(api.createLote).not.toHaveBeenCalled()
    expect(w.text()).toContain('al menos 1')
  })

  it('«ya lo tenía»: la fase en que está y los días de cada una', async () => {
    const w = await montar()
    await w.find('#msal-lote-existente').trigger('click')
    await w.find('#msal-estado').setValue('vegetativo')
    await w.find('#msal-dias-raiz').setValue(10)
    await w.find('#msal-dias-vege').setValue(25)
    expect(w.text()).toMatch(/Arrancó el/)
    await crear(w); await flushPromises()

    const [salaId, payload, dias] = api.createLoteHeredado.mock.calls[0]
    expect(salaId).toBe(99)
    expect(payload.estado).toBe('vegetativo')
    expect(payload.start_date).toBeUndefined() // lo calcula el backend con los días
    expect(dias).toEqual({ dias_semilla_esqueje: 10, dias_vegetativo: 25, dias_floracion: 0 })
  })

  it('en un espacio de vegetativo no ofrece floración', async () => {
    const w = await montar('vegetativo')
    await w.find('#msal-lote-existente').trigger('click')
    const opciones = w.findAll('#msal-estado option').map(o => o.element.value)
    expect(opciones).toEqual(['enraizado', 'vegetativo'])
  })

  it('en un espacio de floración sólo se carga «ya lo tenía», en floración', async () => {
    const w = await montar('floracion')

    expect(w.find('#msal-lote-nuevo').attributes('disabled')).toBeDefined()
    expect(w.find('#msal-lote-existente').attributes('aria-checked')).toBe('true')
    expect(w.findAll('#msal-estado option').map(o => o.element.value)).toEqual(['floracion'])
  })
})
