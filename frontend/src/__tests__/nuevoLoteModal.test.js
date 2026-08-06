import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// El modal pide datos al abrirse; nada de eso hace falta para el caso que interesa.
vi.mock('../lib/api.js', () => ({
  getLoteProximoCodigo: vi.fn(() => Promise.resolve({ data: { codigo: 'L-26-001' } })),
  listGeneticas:        vi.fn(() => Promise.resolve({ data: [] })),
  listPlants:           vi.fn(() => Promise.resolve({ data: [] })),
  createLoteHeredado:   vi.fn(),
  createLoteCosechadoEnSede: vi.fn(),
  listSedes:            vi.fn(() => Promise.resolve({ data: [] })),
}))

const NuevoLoteModal = (await import('../components/lotes/NuevoLoteModal.vue')).default

// Un `watch` que evalúa un computed declarado ANTES que los refs de los que depende explota
// con "Cannot access 'x' before initialization" — y como es un error de RUNTIME, el build pasa
// igual y el síntoma es "hago click en Nuevo lote y no pasa nada". Montar el componente lo
// detecta; compilarlo no.
describe('NuevoLoteModal', () => {
  it('monta sin errores de inicialización', () => {
    setActivePinia(createPinia())
    const errores = []
    const wrapper = mount(NuevoLoteModal, {
      props: { show: false, salas: [] },
      global: {
        stubs: { Teleport: true, AppDatePicker: true, DsSpinner: true },
        config: { errorHandler: (e) => errores.push(e) },
      },
    })

    expect(errores).toEqual([])
    expect(wrapper.exists()).toBe(true)
  })

  it('se abre y renderiza el formulario', async () => {
    setActivePinia(createPinia())
    mount(NuevoLoteModal, {
      props: { show: true, salas: [{ id: 1, nombre: 'Vege 1', kind: 'vegetativo' }] },
      global: { stubs: { AppDatePicker: true, DsSpinner: true }, attachTo: document.body },
    })
    await new Promise((r) => setTimeout(r, 0))

    // El contenido va teleportado a body, no queda dentro del wrapper.
    expect(document.body.innerHTML).toContain('Nuevo lote')
  })
})
