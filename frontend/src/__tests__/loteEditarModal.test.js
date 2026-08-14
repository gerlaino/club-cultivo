import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

const listGeneticas = vi.fn(() => Promise.resolve({
  data: [{ id: 9, nombre: 'Lemon', dias_vegetativo_objetivo: 30, tiempo_floracion: 63, dias_cosecha_objetivo: 14 }],
}))
const updateLote = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api', () => ({
  listGeneticas: (...a) => listGeneticas(...a),
  updateLote:    (...a) => updateLote(...a),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn() }),
}))

let loteActual = null
vi.mock('../stores/lotes', () => ({
  useLotesStore: () => ({ get current() { return loteActual }, fetchOne: vi.fn() }),
}))

const LoteEditarModal = (await import('../components/lotes/LoteEditarModal.vue')).default

// AC (Germán): el modal de editar lote quedó mezclado con cosas que no van.
//  · los días objetivo por fase son de la GENÉTICA, no del lote
//  · un lote enraizando no tiene maceta: tiene bandeja
//  · las fechas de fase se muestran siempre HACIA ATRÁS desde la fase actual
describe('LoteEditarModal', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    document.body.innerHTML = ''
    updateLote.mockClear()
  })

  // El modal vive en un <Teleport to="body">: se consulta el DOM real, no el wrapper.
  // Se abre DESPUÉS de montar, como en la app: el formulario se llena en el watch de `open`,
  // así que montarlo ya abierto lo deja vacío (y cualquier assert pasaría por casualidad).
  const montar = async (lote) => {
    loteActual = lote
    const wrapper = mount(LoteEditarModal, {
      props: { open: false, lote, loteId: lote.id },
      global: { stubs: { DsSpinner: true, AppDatePicker: true } },
      attachTo: document.body,
    })
    await wrapper.setProps({ open: true })
    await new Promise(r => setTimeout(r, 0))
    await wrapper.vm.$nextTick()
    return wrapper
  }
  const $  = (sel) => document.body.querySelector(sel)
  const $$ = (sel) => [...document.body.querySelectorAll(sel)]
  const textos = (sel) => $$(sel).map(n => n.textContent.trim())
  // Por contenido y no por posición: el orden de los campos del modal puede cambiar.
  const selectMaceta = () =>
    $$('select').find(s => [...s.options].some(o => /litros?$/i.test(o.textContent.trim())))

  const lote = (attrs = {}) => ({
    id: 1, codigo: 'L-26-001', estado: 'enraizado', plants_count: 5,
    start_date: '2026-07-01', genetica: { id: 9 }, ...attrs,
  })

  describe('días objetivo por fase', () => {
    it('no se editan por lote: no hay inputs de objetivo', async () => {
      await montar(lote())

      expect(textos('.lem__label').some(t => /Días de (vegetativo|floración|cosecha)/i.test(t))).toBe(false)
    })

    it('se muestran los de la genética elegida, y se dice dónde se editan', async () => {
      await montar(lote())

      const bloque = $('.lem__objetivos').textContent
      expect(bloque).toContain('30')
      expect(bloque).toContain('63')
      expect(bloque).toContain('14')
      expect(bloque).toMatch(/genética/i)
    })
  })

  describe('maceta y estado', () => {
    it('un lote enraizando ofrece bandeja, no "sin especificar"', async () => {
      await montar(lote())

      const opciones = [...selectMaceta().querySelectorAll('option')].map(o => o.textContent.trim())
      expect(opciones[0]).toMatch(/bandeja/i)
    })

    it('elegir litros estando enraizado avisa que el lote prende', async () => {
      const w = await montar(lote())
      expect($('.lem__hint--warn')).toBeNull()

      const select = selectMaceta()
      select.value = '3'
      select.dispatchEvent(new Event('change'))
      await w.vm.$nextTick()

      expect($('.lem__hint--warn').textContent).toMatch(/vegetativo/i)
    })

    it('en vegetativo no hay opción bandeja: ya prendió', async () => {
      await montar(lote({ estado: 'vegetativo', tamanio_maceta: '3.0' }))

      const opciones = [...selectMaceta().querySelectorAll('option')].map(o => o.textContent.trim())
      expect(opciones.some(t => /bandeja/i.test(t))).toBe(false)
    })
  })

  describe('fechas de inicio por fase', () => {
    const fechas = () => textos('.lem__seccion-titulo + .lem__grid .lem__label')

    it('enraizando muestra sólo la fecha de enraizado', async () => {
      await montar(lote())

      expect(fechas()).toEqual([expect.stringMatching(/enraizado/i)])
    })

    it('en vegetativo muestra enraizado y vegetativo', async () => {
      await montar(lote({ estado: 'vegetativo' }))

      expect(fechas().length).toBe(2)
      expect(fechas()[1]).toMatch(/vegetativo/i)
    })

    it('en floración muestra las tres', async () => {
      await montar(lote({ estado: 'floracion' }))

      expect(fechas().length).toBe(3)
      expect(fechas()[2]).toMatch(/floración/i)
    })

    // Escribir historia hacia adelante es inventarla: un lote en vegetativo no tiene fecha de
    // cosecha porque todavía no se cosechó.
    it('nunca ofrece una fase que el lote no alcanzó', async () => {
      await montar(lote({ estado: 'vegetativo' }))

      expect(fechas().some(t => /cosechado/i.test(t))).toBe(false)
    })
  })
})
