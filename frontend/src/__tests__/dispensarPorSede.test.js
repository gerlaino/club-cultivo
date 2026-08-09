import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// Un club con varias sedes mostraba TODO el inventario en una sola lista, y quien dispensa
// tenía que acordarse de cuál era el de su mostrador. Se elige la sede primero y la lista
// queda acotada. Con una sola sede el paso no aparece: no hay nada que elegir.
const STOCKS = [
  { id: 1, cantidad: 100, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 100,
    sede: { id: 10, nombre: 'Finca Norte' } },
  { id: 2, cantidad: 50,  unidad: 'g', forma_producto: 'hash',      precio_sugerido_ars: 300,
    sede: { id: 20, nombre: 'Finca Sur' } },
  { id: 3, cantidad: 30,  unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 120,
    sede: { id: 10, nombre: 'Finca Norte' } },
]

const listStocks = vi.fn(() => Promise.resolve({ data: STOCKS }))
vi.mock('../lib/api.js', () => ({
  listStocks: (...a) => listStocks(...a),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

const PACIENTE = { id: 5, nombre_completo: 'Ana Gómez', cuenta_corriente: {} }

async function montar(stocks = STOCKS) {
  listStocks.mockResolvedValue({ data: stocks })
  setActivePinia(createPinia())
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, paciente: PACIENTE, socioId: PACIENTE.id },
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true } },
  })
  for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))
  return w
}

describe('Dispensar — primero la sede, después su stock', () => {
  beforeEach(() => vi.clearAllMocks())

  it('con varias sedes, ofrece elegir una', async () => {
    const w = await montar()

    expect(w.find('.mnd__sedes').exists()).toBe(true)
    const chips = w.findAll('.mnd__sede-chip').map((c) => c.text())
    expect(chips.some((t) => t.includes('Finca Norte'))).toBe(true)
    expect(chips.some((t) => t.includes('Finca Sur'))).toBe(true)
  })

  it('hasta que no elegís sede, no lista stock suelto de todo el club', async () => {
    const w = await montar()

    expect(w.vm.stocksDisponibles).toHaveLength(0)
    expect(w.text()).toContain('Elegí una sede')
  })

  it('elegida la sede, sólo se ve el stock de esa sede', async () => {
    const w = await montar()

    w.vm.sedeElegida = 10
    await w.vm.$nextTick()

    expect(w.vm.stocksDisponibles.map((s) => s.id)).toEqual([1, 3])
  })

  it('cambiar de sede limpia el stock ya elegido', async () => {
    const w = await montar()
    w.vm.sedeElegida = 10
    await w.vm.$nextTick()
    w.vm.form.stock_id = 1

    w.vm.sedeElegida = 20
    await w.vm.$nextTick()

    expect(w.vm.form.stock_id).toBeNull()
    expect(w.vm.stocksDisponibles.map((s) => s.id)).toEqual([2])
  })

  it('el contador de cada sede dice cuántos productos tiene', async () => {
    const w = await montar()

    const norte = w.vm.sedesConStock.find((s) => s.id === 10)
    expect(norte.items).toBe(2)
  })

  // Con una sola sede pedir que la confirmes sería un clic de peaje.
  it('con una sola sede no aparece el paso, y su stock ya se ve', async () => {
    const w = await montar([STOCKS[0], STOCKS[2]])

    expect(w.find('.mnd__sedes').exists()).toBe(false)
    expect(w.vm.sedeElegida).toBe(10)
    expect(w.vm.stocksDisponibles).toHaveLength(2)
  })

  it('el stock sin sede (pool del club) es una opción más', async () => {
    const w = await montar([...STOCKS, { id: 9, cantidad: 20, unidad: 'g', forma_producto: 'flor_seca', sede: null }])

    expect(w.vm.sedesConStock.map((s) => s.nombre)).toContain('Sin sede (club)')
  })
})
