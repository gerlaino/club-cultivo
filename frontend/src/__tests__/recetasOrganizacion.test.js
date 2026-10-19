import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 19-oct-2026): en una organización, «Nutrientes y recetas» muestra cuánto queda de cada
// nutriente EN CADA SEDE; comprar va por la única puerta (Contabilidad → Nueva compra) y la plata
// la ve sólo administración.
const INSUMOS = [
  { id: 1, nombre: 'Bio-Grow', unidad_medida: 'mililitro', stock_actual: 800, sede_id: 10, sede_nombre: 'Norte', deposito_id: 5, activo: true, costo_promedio_ars: 25, aplicaciones_estimadas: 12 },
  { id: 2, nombre: 'Bio-Grow', unidad_medida: 'mililitro', stock_actual: 50, sede_id: 20, sede_nombre: 'Sur', deposito_id: 6, activo: true, costo_promedio_ars: 25, stock_bajo: true },
  { id: 3, nombre: 'Cal-Mag', unidad_medida: 'mililitro', stock_actual: 300, sede_id: 10, sede_nombre: 'Norte', deposito_id: 5, activo: true, costo_promedio_ars: 40 },
]
let rol = 'admin'
const push = vi.fn()
vi.mock('../lib/api.js', () => ({
  listRecetas: vi.fn(() => Promise.resolve({ data: [] })),
  listInsumos: vi.fn(() => Promise.resolve({ data: { insumos: INSUMOS } })),
  getReceta: vi.fn(), createReceta: vi.fn(), updateReceta: vi.fn(), createInsumo: vi.fn(),
  comprarInsumo: vi.fn(), updateInsumo: vi.fn(), reconteoInsumo: vi.fn(), deleteInsumo: vi.fn(),
}))
vi.mock('vue-router', () => ({ useRouter: () => ({ push }), useRoute: () => ({ query: {} }), RouterLink: { template: '<a><slot /></a>' } }))
vi.mock('../stores/auth', () => ({ useAuthStore: () => ({ user: { role: rol } }) }))
vi.mock('../composables/useUsoPersonal.js', async () => {
  const { ref } = await import('vue')
  return { useUsoPersonal: () => ({ esPersonal: ref(false) }) }
})
vi.mock('../composables/useRecargaEnCambios.js', () => ({ useRecargaEnCambios: () => {} }))
vi.mock('../lib/camas.js', () => ({ reglasSueloVivo: () => ({ usos_receta: ['riego'], usos_receta_labels: { riego: 'Riego' }, unidades_por_uso: { riego: ['ml_l'] } }) }))

async function montar() {
  setActivePinia(createPinia())
  const V = (await import('../views/RecetasView.vue')).default
  const w = mount(V, { global: { stubs: { RouterLink: true, DsSpinner: true, DosisEtiqueta: true, Teleport: true } } })
  await flushPromises()
  return w
}

describe('Nutrientes y recetas en una organización', () => {
  beforeEach(() => { push.mockClear(); rol = 'admin' })

  it('agrupa por producto con una fila por sede, y avisa la que queda poco', async () => {
    const w = await montar()
    const productos = w.findAll('.rc__producto')
    expect(productos.map(p => p.find('.rc__producto-nombre').text())).toEqual(['Bio-Grow ml', 'Cal-Mag ml'])
    const filas = productos[0].findAll('.rc__nutriente')
    expect(filas.map(f => f.find('.rc__nutriente-sede').text())).toEqual(['Norte', 'Sur'])
    expect(filas[1].classes()).toContain('rc__nutriente--bajo')
  })

  it('filtrar por una sede deja sólo lo de esa sede', async () => {
    const w = await montar()
    await w.findAll('.rc__tab').find(t => t.text() === 'Sur').trigger('click')
    expect(w.findAll('.rc__producto').map(p => p.find('.rc__producto-nombre').text())).toEqual(['Bio-Grow ml'])
  })

  it('«Cargar compra» lleva a la compra de Contabilidad con el producto y su depósito', async () => {
    const w = await montar()
    await w.findAll('button').find(b => b.text().includes('Cargar compra')).trigger('click')
    expect(push).toHaveBeenCalledWith({ name: 'contabilidad', query: { nuevo: 'compra', deposito: 5, nombre: 'Bio-Grow', unidad: 'mililitro' } })
  })

  it('el cultivador ve el stock pero no la plata ni la compra', async () => {
    rol = 'cultivador'
    const w = await montar()
    expect(w.text()).toContain('quedan')
    expect(w.text()).not.toContain('$')
    expect(w.findAll('button').some(b => b.text().includes('Cargar compra'))).toBe(false)
  })
})
