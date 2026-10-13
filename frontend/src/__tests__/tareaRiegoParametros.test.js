import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { defineComponent, h } from 'vue'

// AC (Germán, 12-oct-2026): una tarea de riego dice cómo regar (receta, litros, pH, EC), igual que
// un registro de riego. Al completarla se registra el riego con eso precargado y la tarea queda
// hecha; las tareas de riego que no dicen nada se siguen cerrando con un toque.
const api = vi.hoisted(() => ({ getLote: vi.fn(), getSala: vi.fn() }))
vi.mock('../lib/api.js', () => ({ getLote: (...a) => api.getLote(...a), getSala: (...a) => api.getSala(...a) }))
const completar = vi.fn()
vi.mock('../stores/tareas.js', () => ({ useTareasStore: () => ({ completar: (...a) => completar(...a) }) }))

// El registro real necesita medio sistema; acá alcanza con ver con qué se abre y simular el guardado.
const RegistroStub = defineComponent({
  name: 'RegistroLoteModal',
  props: ['modelValue', 'lote', 'accionInicial', 'riegoInicial'],
  emits: ['saved', 'update:modelValue'],
  setup: (p) => () => h('div', { class: 'registro-stub' }, JSON.stringify({ accion: p.accionInicial, riego: p.riegoInicial })),
})

const { pideRegistroDeRiego, resumenRiego } = await import('../composables/useCompletarRiego.js')

const TAREA = {
  id: 9, titulo: 'Regar flora', tipo: 'riego', horas_estimadas: null,
  lote: { id: 4, codigo: 'L-26-043' },
  riego: { receta: { id: 2, nombre: 'Flora 1' }, litros: 20, ph: 6.2, ec: 1.4 },
}

describe('Cuándo «Hecho» pide registrar el riego', () => {
  it('sólo la de riego que dice cómo regar y tiene dónde', () => {
    expect(pideRegistroDeRiego(TAREA)).toBe(true)
    expect(pideRegistroDeRiego({ ...TAREA, riego: null })).toBe(false)
    expect(pideRegistroDeRiego({ ...TAREA, lote: null, sala: null })).toBe(false)
    expect(pideRegistroDeRiego({ ...TAREA, tipo: 'poda' })).toBe(false)
  })

  it('el resumen se lee en una línea', () => {
    expect(resumenRiego(TAREA)).toBe('Receta Flora 1 · 20 L · pH 6,2 · EC 1,4')
    expect(resumenRiego({ riego: { receta: null, litros: 5, ph: null, ec: null } })).toBe('Agua sola · 5 L')
  })
})

describe('Completar una tarea de riego', () => {
  beforeEach(() => { completar.mockReset(); api.getLote.mockReset(); setActivePinia(createPinia()) })

  async function montar() {
    const V = (await import('../components/ModalCompletarTarea.vue')).default
    return mount(V, { props: { show: true, tarea: TAREA },
      global: { stubs: { teleport: true, transition: false, RegistroLoteModal: RegistroStub, RegistroSalaModal: true }, directives: { modal: {} } } })
  }

  it('muestra cómo regar', async () => {
    const w = await montar()
    expect(w.find('[data-testid="completar-riego"]').text()).toContain('Receta Flora 1 · 20 L · pH 6,2 · EC 1,4')
  })

  it('«Registrar el riego» abre el registro del lote con eso precargado', async () => {
    api.getLote.mockResolvedValue({ data: { id: 4, codigo: 'L-26-043', estado: 'floracion' } })
    const w = await montar()
    await w.findAll('button').find(b => b.text().includes('Registrar el riego')).trigger('click')
    await flushPromises()

    expect(api.getLote).toHaveBeenCalledWith(4)
    const abierto = JSON.parse(w.find('.registro-stub').text())
    expect(abierto).toEqual({ accion: 'riego', riego: { receta_id: 2, litros: 20, ph: 6.2, ec: 1.4 } })
  })

  it('guardado el riego, la tarea queda completada', async () => {
    api.getLote.mockResolvedValue({ data: { id: 4 } })
    completar.mockResolvedValue({ tarea: { id: 9 } })
    const w = await montar()
    await w.findAll('button').find(b => b.text().includes('Registrar el riego')).trigger('click')
    await flushPromises()
    w.findComponent(RegistroStub).vm.$emit('saved')
    await flushPromises()

    expect(completar).toHaveBeenCalledWith(9, null, null, {})
    expect(w.emitted('completada')).toBeTruthy()
  })

  it('«Sólo marcarla hecha» la cierra sin registrar nada', async () => {
    completar.mockResolvedValue({ tarea: { id: 9 } })
    const w = await montar()
    await w.findAll('button').find(b => b.text().includes('Sólo marcarla hecha')).trigger('click')
    await flushPromises()
    expect(api.getLote).not.toHaveBeenCalled()
    expect(completar).toHaveBeenCalled()
  })
})
