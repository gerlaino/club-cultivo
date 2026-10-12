import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'

// AC (Germán, 29-sep): el informe de stock muestra los stocks con su información —propio y
// externo—, qué hay hoy por unidad (nunca sumado entre unidades), el valor, qué vence y qué no se
// mueve. La pantalla muestra lo que manda el backend.
const DATA = {
  resena: 'Qué hay hoy…',
  filtros: { activo: true, descripcion: 'sólo stock externo' },
  hoy: {
    por_producto: [
      { producto: 'flor_seca', unidad: 'g', origen: 'propio', stocks: 2, queda: 150, en_mesa: 20, comprometido: 15, libre: 135 },
      { producto: 'flor_seca', unidad: 'g', origen: 'externo', stocks: 1, queda: 50, en_mesa: 0, comprometido: 0, libre: 50 },
      { producto: 'otro', unidad: 'g', origen: 'propio', stocks: 1, queda: 978, en_mesa: 0, comprometido: 0, libre: 978 },
      { producto: 'preroll', unidad: 'un', origen: 'externo', stocks: 1, queda: 12, en_mesa: 0, comprometido: 0, libre: 12 },
    ],
    flor_seca_disponible: 185,
    stocks_con_saldo: 4, valor_costo: 60000, valor_venta: 190000, sin_costo: 1, sin_precio: 0,
  },
  stocks: [{ id: 1, numero: 'ST-001', producto: 'flor_seca', unidad: 'g', genetica: 'Kush', origen: 'externo', de_donde: 'Coop Sur',
             habia: 0, ingreso: 50, dispensado: 0, merma: 0, otras_salidas: 0, ajustes: 0, quedaba: 50, queda: 50, libre: 50 },
           // El caso de la captura (7-oct): había 176,8; 33 + 27 − 43 = 193,8.
           { id: 2, numero: 'ST-26-0024', producto: 'flor_seca', unidad: 'g', genetica: 'Fruti Punchi', origen: 'externo', de_donde: 'Interno',
             habia: 176.8, ingreso: 33, dispensado: 43, merma: 0, otras_salidas: 0, ajustes: 27, quedaba: 193.8, queda: 193.8, libre: 193.8,
             ajustes_detalle: [{ fecha: '2026-10-02', gramos: 30, quien: 'Ana', notas: 'Recuento' }, { fecha: '2026-10-05', gramos: -3, quien: 'Ana', notas: null }] }],
  periodo: [{ unidad: 'g', ingreso: 50, dispensado: 30, merma: 2, otras_salidas: 0, ajustes: 0 }],
  vencen: [], sin_movimiento: [],
}
const get = vi.fn(() => Promise.resolve({ data: DATA }))
vi.mock('../lib/api.js', () => ({ default: { get: (...a) => get(...a) } }))
vi.mock('../composables/useInformePdf.js', () => ({
  useInformePdf: () => ({ exporting: false, exportarPdf: vi.fn(), exportarXlsx: vi.fn() }),
}))

describe('Informe de stock — pantalla', () => {
  let w
  beforeEach(async () => {
    const { default: Vista } = await import('../views/auditor/InformeStockView.vue')
    w = mount(Vista, { global: { stubs: { SelectorPeriodo: true, FiltrosInforme: true } } })
    await new Promise(r => setTimeout(r, 0)); await w.vm.$nextTick()
  })

  // AC (Germán, 7-oct): «¿ajustes es la cantidad de veces?». No: gramos. Y cada fila cierra.
  it('cada fila muestra cuánto había al empezar y cuánto quedaba al final', () => {
    const fila = w.findAll('tbody tr').find(r => r.text().includes('ST-26-0024'))
    expect(fila.text()).toContain('176,8')
    expect(fila.text()).toContain('193,8')
    expect(w.text()).toContain('Había')
    expect(w.text()).toContain('Quedaba')
  })

  it('tocar los ajustes muestra cada uno: cuándo, cuánto, quién y por qué', async () => {
    await w.find('.inf__ajustes-btn').trigger('click')
    const det = w.find('.inf__ajustes')
    expect(det.text()).toContain('Recuento')
    expect(det.text()).toContain('sin motivo anotado')
    expect(det.text()).toContain('Ana')
  })

  // AC (Germán, 12-oct-2026, Mitocondria): Stock decía 2.865 g de flor y el informe 3.843 g porque
  // sumaba la flor con 978 g de «otro». La flor seca disponible es la que manda el backend, y los
  // otros productos van cada uno aparte.
  it('la flor seca disponible no se suma con otro producto en gramos', () => {
    const kpis = w.findAll('.inf__kpi').map(k => k.text())
    expect(kpis.find(t => t.includes('Flor seca disponible'))).toContain('185 g')
    expect(kpis.find(t => t.includes('Otro (g)'))).toContain('978 g')
    expect(kpis.some(t => t.includes('1.163'))).toBe(false)   // 185 + 978 sumados
  })

  it('pide /informes/stock', () => {
    expect(get).toHaveBeenCalledWith('/informes/stock', expect.anything())
  })

  it('cada producto aparte: propio y externo juntos, gramos y unidades separados', () => {
    const kpis = w.findAll('.inf__kpi').map(k => k.text())
    expect(kpis.some(t => t.includes('12 un') && t.includes('Preroll (un)'))).toBe(true)
    const filas = w.findAll('tbody tr').map(r => r.text())
    expect(filas.some(t => t.startsWith('Otro (g)') && t.includes('978'))).toBe(true)
  })

  it('dice que está filtrado', () => {
    expect(w.find('.inf__filtrado').text()).toContain('sólo stock externo')
  })

  it('el stock externo figura con su proveedor', () => {
    const fila = w.findAll('tbody tr').find(r => r.text().includes('ST-001'))
    expect(fila.text()).toContain('Externo')
    expect(fila.text()).toContain('Coop Sur')
  })

  it('el valor, y cuántos no tienen costo', () => {
    expect(w.text()).toContain('1 sin costo cargado')
  })
})
