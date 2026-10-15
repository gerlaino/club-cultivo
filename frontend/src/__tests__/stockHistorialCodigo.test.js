import { describe, it, expect, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 15-oct-2026): «quiero poder saber qué stock es cada uno» (el Historial mostraba
// «Flor seca · Asignado · Pagola · 28g» sin el código) y «hay un stock que tenemos con merma, y
// queremos revisarlo pero no lo encontramos» (ST-26-0013 salía en el informe, no en la pantalla).
const HIST = [
  { id: 13, numero_lote_producto: 'ST-26-0013', forma_producto: 'flor_seca', estado: 'agotado', cantidad: 0,
    origen: 'compra_externa', genetica: { id: 2, nombre: 'Fruti Punchi' }, lote: null, sede: { id: 1, nombre: 'Pagola' }, created_at: '2026-09-08T12:00:00Z' },
  { id: 20, numero_lote_producto: 'ST-26-0020', forma_producto: 'flor_seca', estado: 'asignado', cantidad: 28,
    origen: 'compra_externa', genetica: { id: 3, nombre: 'Vita Mac' }, lote: null, sede: { id: 1, nombre: 'Pagola' }, created_at: '2026-10-07T12:00:00Z' },
]
vi.mock('../lib/api.js', () => ({
  listStocksPendientes: vi.fn(() => Promise.resolve({ data: [] })),
  listStocks:           vi.fn(() => Promise.resolve({ data: [] })),
  listStocksHistorial:  vi.fn(() => Promise.resolve({ data: HIST })),
  listStockInventario:  vi.fn(() => Promise.resolve({ data: { stocks: [], meta: { total: 0, page: 1, per_page: 25 }, totales: { total_g: 0, reservado_g: 0, items: 0, sedes_con_stock: 0, por_producto: [], derivados_items: 0, vencidos: 0, por_vencer: 0 } } })),
  asignarStock: vi.fn(), ajustarStock: vi.fn(), descartarStock: vi.fn(),
  getStockMovimientos: vi.fn(() => Promise.resolve({ data: [] })),
  listSedes: vi.fn(() => Promise.resolve({ data: [{ id: 1, nombre: 'Pagola', tipo: 'social' }] })),
  createStock: vi.fn(), updateStock: vi.fn(),
  getPreferences: vi.fn(() => Promise.resolve({ data: {} })), updatePreferences: vi.fn(),
  listGeneticas: vi.fn(() => Promise.resolve({ data: [] })),
}))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }) }))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn(), back: vi.fn() }) }))

async function historial () {
  setActivePinia(createPinia())
  const V = (await import('../views/admin/AdminStocksPendientesView.vue')).default
  const w = mount(V, { global: { stubs: { AppDatePicker: true, RouterLink: { props: ['to'], template: '<a :href="to"><slot /></a>' } } } })
  await flushPromises()
  const tab = w.findAll('button').find(b => b.text().startsWith('Historial'))
  await tab.trigger('click')
  await flushPromises()
  return w
}

describe('Stock · Historial: qué stock es cada uno', () => {
  it('cada fila dice su código', async () => {
    const w = await historial()
    const filas = w.findAll('[data-testid="hist-fila"]')
    expect(filas.map(f => f.text())).toEqual([expect.stringContaining('ST-26-0013'), expect.stringContaining('ST-26-0020')])
  })

  it('se busca por código y aparece el agotado con merma', async () => {
    const w = await historial()
    await w.find('[data-testid="hist-buscar"]').setValue('st-26-0013')
    const filas = w.findAll('[data-testid="hist-fila"]')
    expect(filas).toHaveLength(1)
    expect(filas[0].text()).toContain('Fruti Punchi')
  })

  it('también por genética, sin tildes ni mayúsculas', async () => {
    const w = await historial()
    await w.find('[data-testid="hist-buscar"]').setValue('vita')
    expect(w.findAll('[data-testid="hist-fila"]').map(f => f.text())).toEqual([expect.stringContaining('ST-26-0020')])
  })

  it('tocar la fila abre ese stock', async () => {
    const w = await historial()
    expect(w.find('[data-testid="hist-fila"]').attributes('href')).toBe('/admin/stock/13')
  })
})
