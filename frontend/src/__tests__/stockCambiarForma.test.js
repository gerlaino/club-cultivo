import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// QUÉ ES un producto se puede corregir.
//
// Un stock cargado como `prensado` porque todavía no existía `preroll` no puede quedar mal para
// siempre: la forma y su unidad son una etiqueta, y una etiqueta equivocada se arregla.
//
// LA SALVEDAD ES EL EJERCICIO CERRADO: ahí cambiar la unidad reinterpretaría cantidades ya
// asentadas. Lo decide el backend; la pantalla no tiene que ofrecer lo que va a rebotar, ni
// esconderlo sin decir por qué.

const BASE = {
  id: 7, forma_producto: 'prensado', unidad: 'g', origen: 'compra_externa',
  cantidad: 20, cantidad_inicial: 20, cantidad_disponible_real: 20, gramos_reservados: 0,
  precio_sugerido_ars: 8500, costo_unitario_ars: 4000, proveedor: 'X', descripcion: '',
  disponibilidad: 'ambas', estado: 'asignado', numero_lote_producto: 'ST-26-0007',
  puede_cambiar_forma: true, dispensas_cerradas: 0,
}

let stock = { ...BASE }
const getStock    = vi.fn(() => Promise.resolve({ data: { data: stock } }))
const updateStock = vi.fn(() => Promise.resolve({ data: {} }))

vi.mock('../lib/api.js', () => ({
  getStock: (...a) => getStock(...a),
  updateStock: (...a) => updateStock(...a),
  asignarStock: vi.fn(), ajustarStock: vi.fn(), descartarStock: vi.fn(), deleteStock: vi.fn(),
  getStockMovimientos: vi.fn(() => Promise.resolve({ data: [] })),
  listSedes: vi.fn(() => Promise.resolve({ data: [] })),
  producirStock: vi.fn(),
  listPesajesManicura: vi.fn(() => Promise.resolve({ data: [] })),
  reajustarPesoPesajeManicura: vi.fn(),
  listGeneticas: vi.fn(() => Promise.resolve({ data: [] })),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: '7' } }),
  useRouter: () => ({ push: vi.fn(), back: vi.fn() }),
}))

async function montar () {
  setActivePinia(createPinia())
  const { default: Vista } = await import('../views/admin/AdminStockDetailView.vue')
  const w = mount(Vista, { global: { stubs: { RouterLink: true, DsSpinner: true, Teleport: true } } })
  await flushPromises(); await flushPromises()
  return w
}

const editar = async (w) => {
  await w.findAll('button').find(b => /editar/i.test(b.text())).trigger('click')
  await flushPromises()
}
const campoForma = (w) => w.findAll('select').find(s => s.findAll('option').some(o => o.text() === 'Preroll'))
const campoUnidad = (w) => w.findAll('select').find(s => s.findAll('option').some(o => /unidades/.test(o.text())))

beforeEach(() => { vi.clearAllMocks(); stock = { ...BASE } })

describe('Corregir qué es un stock', () => {
  it('se puede elegir otro producto, y la unidad se deriva sola', async () => {
    const w = await montar()
    await editar(w)

    await campoForma(w).setValue('preroll')
    expect(campoUnidad(w).element.value).toBe('un')
    // Y avisa qué significa el cambio antes de guardarlo.
    expect(w.text()).toContain('pasan a leerse como un')
  })

  it('y se manda al backend', async () => {
    const w = await montar()
    await editar(w)
    await campoForma(w).setValue('preroll')
    await w.findAll('button').find(b => /guardar/i.test(b.text())).trigger('click')
    await flushPromises()

    expect(updateStock).toHaveBeenCalledWith(7, expect.objectContaining({
      forma_producto: 'preroll', unidad: 'un',
    }))
  })

  // Mandarlo siempre haría que el backend evalúe la regla del período cerrado en cada guardado,
  // y una corrección de precio rebotaría por algo que nadie tocó.
  it('pero no si no cambió', async () => {
    const w = await montar()
    await editar(w)
    await w.findAll('button').find(b => /guardar/i.test(b.text())).trigger('click')
    await flushPromises()

    const payload = updateStock.mock.calls[0][1]
    expect(payload).not.toHaveProperty('forma_producto')
    expect(payload).not.toHaveProperty('unidad')
  })

  describe('con el ejercicio contable cerrado', () => {
    beforeEach(() => { stock = { ...BASE, puede_cambiar_forma: false, dispensas_cerradas: 2 } })

    it('no deja cambiarlo', async () => {
      const w = await montar()
      await editar(w)

      expect(campoForma(w).attributes('disabled')).toBeDefined()
      expect(campoUnidad(w).attributes('disabled')).toBeDefined()
    })

    // Esconderlo sin decir por qué es peor: parece que la app está rota.
    it('y explica por qué, y qué hacer', async () => {
      const w = await montar()
      await editar(w)

      expect(w.text()).toContain('período contable cerrado')
      expect(w.text()).toContain('reabrí el período')
      expect(w.text()).toContain('2 veces')
    })

    it('el resto del producto se sigue editando: no queda congelado entero', async () => {
      const w = await montar()
      await editar(w)

      const precio = w.findAll('input[type="number"]').find(i => !i.attributes('disabled'))
      expect(precio).toBeTruthy()
    })
  })
})
