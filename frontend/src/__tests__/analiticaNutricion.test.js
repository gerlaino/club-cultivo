import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// AC (Germán, 29-sep-2026): comparar lo que recibió cada lote y cómo rindió.
// - los lotes llegan por la URL (la ficha del lote manda `?lotes=12`) y se piden al backend;
// - la tabla tiene una fila por producto que recibió ALGUNO, vacía en el que no;
// - se agregan lotes del selector hasta 4, y «los de la misma genética» suma los que faltan;
// - el CSV lleva una columna por lote.
const api = vi.hoisted(() => ({ getAnaliticaNutricion: vi.fn(), getAnaliticaNutricionLotes: vi.fn() }))
vi.mock('../lib/api.js', () => ({
  getAnaliticaNutricion: (...a) => api.getAnaliticaNutricion(...a),
  getAnaliticaNutricionLotes: (...a) => api.getAnaliticaNutricionLotes(...a),
}))
vi.mock('chart.js/auto', () => ({ default: vi.fn(() => ({ destroy: vi.fn() })) }))
const route = vi.hoisted(() => ({ query: { tab: 'nutricion', lotes: '1,2' } }))
const replace = vi.fn()
vi.mock('vue-router', () => ({ useRoute: () => route, useRouter: () => ({ replace }) }))

const lote = (id, codigo, prods, extra = {}) => ({
  id, codigo, genetica: 'Kush', plantas: 4, estado_label: 'Curado', dias: { vegetativo: 30, floracion: 60 },
  rendimiento_g: 400, g_por_planta: 100, g_m2: 200,
  totales: { aplicaciones: 2, litros: 20, litros_por_planta: 5, ph: 6.1, costo_ars: 500, costo_por_planta: 125, costo_por_gramo: 1.25, sin_cantidades: 0 },
  por_producto: prods, por_fase: { vegetativo: { ec: 1.2 } }, por_semana: [{ semana_label: 'V1', ec: 1.2 }], ...extra,
})
const DATA = {
  con_costo: true, semanas: ['V1'],
  productos: [{ clave: 'bio-grow|mililitro', nombre: 'Bio-Grow', unidad: 'mililitro' }, { clave: 'bloom|mililitro', nombre: 'Bloom', unidad: 'mililitro' }],
  lotes: [
    lote(1, 'L-1', { 'bio-grow|mililitro': { cantidad: 40, por_planta: 10, veces: 2 }, 'bloom|mililitro': { cantidad: 80, por_planta: 20, veces: 1 } }),
    lote(2, 'L-2', { 'bio-grow|mililitro': { cantidad: 10, por_planta: 5, veces: 1 } }, { rendimiento_g: null, g_por_planta: null }),
  ],
}
const CANDIDATOS = [
  { id: 1, codigo: 'L-1', genetica_id: 7, genetica: 'Kush', estado_label: 'Curado' },
  { id: 2, codigo: 'L-2', genetica_id: 7, genetica: 'Kush', estado_label: 'Vegetativo' },
  { id: 3, codigo: 'L-3', genetica_id: 7, genetica: 'Kush', estado_label: 'Curado' },
  { id: 4, codigo: 'L-4', genetica_id: 9, genetica: 'Haze', estado_label: 'Curado' },
]

async function montar() {
  api.getAnaliticaNutricion.mockResolvedValue({ data: DATA })
  api.getAnaliticaNutricionLotes.mockResolvedValue({ data: { lotes: CANDIDATOS } })
  const C = (await import('../components/analitica/AnaliticaNutricion.vue')).default
  const w = mount(C, { global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } } })
  await flushPromises()
  return w
}

describe('Analítica → Nutrición', () => {
  beforeEach(() => { Object.values(api).forEach(f => f.mockReset()); replace.mockReset(); route.query = { tab: 'nutricion', lotes: '1,2' } })

  it('pide los lotes que vienen en la URL', async () => {
    await montar()
    expect(api.getAnaliticaNutricion).toHaveBeenCalledWith({ lote_ids: [1, 2] })
  })

  it('una fila por producto que recibió alguno, vacía en el que no; el que está en curso lo dice', async () => {
    const w = await montar()
    const bloom = w.findAll('tbody tr').find(r => r.text().startsWith('Bloom'))
    const celdas = bloom.findAll('td').map(td => td.text())
    expect(celdas[1]).toContain('20 ml')
    expect(celdas[2]).toBe('—')
    expect(w.text()).toContain('en curso')
  })

  it('«los de la misma genética» suma los que faltan, sin pasar de 4', async () => {
    const w = await montar()
    const boton = w.findAll('button').find(b => b.text().includes('misma genética'))
    expect(boton.text()).toContain('(1)')   // L-3 es Kush; L-4 es Haze
    await boton.trigger('click')
    await flushPromises()
    expect(api.getAnaliticaNutricion).toHaveBeenLastCalledWith({ lote_ids: [1, 2, 3] })
  })

  it('el CSV lleva una columna por lote', async () => {
    const w = await montar()
    const { headers, rows } = w.vm.csv()
    expect(headers).toEqual(['', 'L-1', 'L-2'])
    expect(rows.find(r => r[0].startsWith('Bloom'))).toEqual(['Bloom (ml total)', 80, undefined])
  })
})
