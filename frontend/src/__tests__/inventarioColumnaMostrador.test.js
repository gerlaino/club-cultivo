import { describe, it, expect, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// EL INVENTARIO TIENE QUE DECIR DÓNDE ESTÁ EL PRODUCTO.
//
// Con el frasco entero cargado a la mesa del mostrador, la columna «Actual» mostraba
// `cantidad_disponible_real` —que resta la mesa— y decía "0.0g" en rojo, mientras el KPI de
// arriba decía 18. El socio de Germán: "El stock está, pero no lo muestra en el listado. Está en
// mostrador. De alguna manera lo tendría que mostrar en el listado".
//
// La mesa es un LUGAR, no un compromiso: «Actual» dice lo que se puede entregar —el mismo número
// que valida el backend— y la columna «Mostrador» dice cuánto de eso está arriba.

const FILA = {
  id: 13, numero_lote_producto: 'ST-26-0013', forma_producto: 'flor_seca', unidad: 'g',
  origen: 'compra_externa', regulatorio: false, estado: 'asignado',
  cantidad: 18, cantidad_inicial: 100,
  cantidad_disponible_real: 0,        // el frasco entero está sobre la mesa
  disponible_para_entregar: 18,       // …y se puede entregar igual
  en_mostrador: true, en_mostrador_g: 18,
  gramos_reservados: 18, reservado: 0, apartados_evento: [],
  sede: { id: 1, nombre: 'Pagola' }, lote: null, genetica: { id: 2, nombre: 'Fruti Punchi' },
  created_at: '2026-09-08T12:00:00Z', descripcion: null,
}

vi.mock('../lib/api.js', () => ({
  listStocksPendientes:  vi.fn(() => Promise.resolve({ data: [] })),
  listStocks:            vi.fn(() => Promise.resolve({ data: [] })),
  listStocksHistorial:   vi.fn(() => Promise.resolve({ data: { movimientos: [], meta: { total: 0 } } })),
  listStockInventario:   vi.fn(() => Promise.resolve({ data: {
    stocks: [FILA],
    meta: { total: 1, page: 1, per_page: 25 },
    totales: { total_g: 18, reservado_g: 0, items: 1, sedes_con_stock: 1,
               derivados_items: 0, vencidos: 0, por_vencer: 0 },
  } })),
  asignarStock: vi.fn(), ajustarStock: vi.fn(), descartarStock: vi.fn(),
  getStockMovimientos: vi.fn(() => Promise.resolve({ data: [] })),
  listSedes:    vi.fn(() => Promise.resolve({ data: [{ id: 1, nombre: 'Pagola', tipo: 'social' }] })),
  createStock:  vi.fn(), updateStock: vi.fn(),
  getPreferences:    vi.fn(() => Promise.resolve({ data: { umbral_stock_g: 10 } })),
  updatePreferences: vi.fn(),
  listGeneticas:     vi.fn(() => Promise.resolve({ data: [] })),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn(), back: vi.fn() }) }))

async function montar () {
  setActivePinia(createPinia())
  const Vista = (await import('../views/admin/AdminStocksPendientesView.vue')).default
  const wrapper = mount(Vista, { global: { stubs: { AppDatePicker: true } } })
  await flushPromises()
  return wrapper
}

describe('Inventario: dónde está el producto', () => {
  it('«Actual» muestra lo que se puede entregar, no el frasco menos la mesa', async () => {
    const w = await montar()
    expect(w.find('.stk__inv-td-actual').text()).toBe('18.0g')
    w.unmount()
  })

  // El umbral de esta organización es 10 g: los 18 que están sobre la mesa NO son stock bajo.
  // Restando la mesa, la fila daba 0.0 y se pintaba en rojo con el frasco lleno adelante.
  it('no lo pinta como stock bajo: los 18 g están y se pueden entregar', async () => {
    const w = await montar()
    expect(w.find('.stk__inv-td-actual').classes()).not.toContain('stk__inv-td-bajo')
    w.unmount()
  })

  it('la columna Mostrador dice cuánto hay sobre la mesa', async () => {
    const w = await montar()
    const encabezados = w.findAll('.stk__inv-th-btn').map(b => b.text().replace(/[▲▼]/g, '').trim())
    expect(encabezados).toContain('Mostrador')
    expect(w.find('.stk__inv-td-mesa').text()).toBe('18.0g')
    w.unmount()
  })

  it('el KPI de arriba dice lo mismo que la fila', async () => {
    const w = await montar()
    expect(w.text()).toContain('18.0')
    w.unmount()
  })
})
