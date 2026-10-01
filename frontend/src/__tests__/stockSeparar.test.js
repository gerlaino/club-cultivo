import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 1-oct-2026): separar los bajos de los copones de un frasco YA creado. Cada frasco
// nuevo con su nombre, su cantidad y su precio; este frasco se puede renombrar; sólo se separa lo
// guardado y libre (`separable` del backend) y algo tiene que quedar acá.
const BASE = {
  id: 7, forma_producto: 'flor_seca', unidad: 'g', origen: 'lote', lote_id: 3, sede_id: 1,
  cantidad: 100, cantidad_inicial: 100, cantidad_disponible_real: 100, gramos_reservados: 0, separable: 100,
  precio_sugerido_ars: 150, estado: 'asignado', numero_lote_producto: 'ST-26-0007', descripcion: null,
  puede_cambiar_forma: true, dispensas_cerradas: 0,
}
let stock = { ...BASE }
const separarStock = vi.fn(() => Promise.resolve({ data: { nuevos: [{ id: 8, numero_lote_producto: 'ST-26-0008' }] } }))
vi.mock('../lib/api.js', () => ({
  getStock: vi.fn(() => Promise.resolve({ data: { data: stock } })),
  updateStock: vi.fn(), asignarStock: vi.fn(), ajustarStock: vi.fn(), descartarStock: vi.fn(), deleteStock: vi.fn(),
  getStockMovimientos: vi.fn(() => Promise.resolve({ data: [] })), listSedes: vi.fn(() => Promise.resolve({ data: [] })),
  producirStock: vi.fn(), listPesajesManicura: vi.fn(() => Promise.resolve({ data: [] })), reajustarPesoPesajeManicura: vi.fn(),
  listGeneticas: vi.fn(() => Promise.resolve({ data: [] })), separarStock: (...a) => separarStock(...a),
}))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }) }))
vi.mock('vue-router', () => ({ useRoute: () => ({ params: { id: '7' } }), useRouter: () => ({ push: vi.fn(), back: vi.fn() }) }))

async function montar() {
  setActivePinia(createPinia())
  const { default: V } = await import('../views/admin/AdminStockDetailView.vue')
  const w = mount(V, { global: { stubs: { RouterLink: true, DsSpinner: true, Teleport: true }, directives: { modal: {} } } })
  await flushPromises(); await flushPromises()
  return w
}
const abrir = async (w) => { await w.findAll('.sd__action').find(b => b.text().includes('Separar en frascos')).trigger('click'); await flushPromises() }
const btnSeparar = (w) => w.findAll('.sd__btn-primary').find(b => b.text().includes('Separar'))

describe('Separar un frasco en varios', () => {
  beforeEach(() => { vi.clearAllMocks(); stock = { ...BASE } })

  it('separa los bajos con su precio y renombra este frasco', async () => {
    const w = await montar()
    await abrir(w)
    const filas = w.findAll('.sd__separar-fila')
    expect(filas[0].find('input[type=text]').element.value).toBe('Bajos')
    await filas[0].findAll('input[type=number]')[0].setValue(30)
    await filas[0].findAll('input[type=number]')[1].setValue(80)
    await w.find('input[placeholder="Ej: Copones"]').setValue('Copones')
    expect(w.find('.sd__separar-resumen').text()).toContain('quedan 70 g')
    await btnSeparar(w).trigger('click'); await flushPromises()
    expect(separarStock).toHaveBeenCalledWith(7, {
      descripcion_origen: 'Copones',
      frascos: [{ descripcion: 'Bajos', gramos: 30, precio_sugerido_ars: 80 }],
    })
  })

  it('no deja separar más de lo guardado y libre, ni todo el frasco', async () => {
    stock = { ...BASE, separable: 40 } // 60 sobre la mesa
    const w = await montar()
    await abrir(w)
    expect(w.text()).toContain('hasta 40 g')
    const fila = w.findAll('.sd__separar-fila')[0]
    await fila.findAll('input[type=number]')[0].setValue(50)
    expect(btnSeparar(w).attributes('disabled')).toBeDefined()
    expect(w.find('.sd__separar-resumen').text()).toContain('más de lo que se puede separar')
    await fila.findAll('input[type=number]')[0].setValue(40)
    expect(btnSeparar(w).attributes('disabled')).toBeUndefined()
  })

  it('sin nada libre para separar, la acción no se ofrece', async () => {
    stock = { ...BASE, separable: 0 }
    const w = await montar()
    const accion = w.findAll('.sd__action').find(b => b.text().includes('Separar en frascos'))
    expect(accion.attributes('disabled')).toBeDefined()
  })
})
