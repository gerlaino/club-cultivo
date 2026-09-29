import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'

// AC (Germán, 29-sep): el informe de stock muestra los stocks con su información —propio y
// externo—, qué hay hoy por unidad (nunca sumado entre unidades), el valor, qué vence y qué no se
// mueve. La pantalla muestra lo que manda el backend.
const DATA = {
  resena: 'Qué hay hoy…',
  filtros: { activo: true, descripcion: 'sólo stock externo' },
  hoy: {
    por_unidad: [
      { unidad: 'g', origen: 'propio', stocks: 2, queda: 150, en_mesa: 20, comprometido: 15, libre: 135 },
      { unidad: 'g', origen: 'externo', stocks: 1, queda: 50, en_mesa: 0, comprometido: 0, libre: 50 },
      { unidad: 'un', origen: 'externo', stocks: 1, queda: 12, en_mesa: 0, comprometido: 0, libre: 12 },
    ],
    stocks_con_saldo: 4, valor_costo: 60000, valor_venta: 190000, sin_costo: 1, sin_precio: 0,
  },
  stocks: [{ id: 1, numero: 'ST-001', producto: 'flor_seca', unidad: 'g', genetica: 'Kush', origen: 'externo', de_donde: 'Coop Sur',
             ingreso: 50, dispensado: 0, merma: 0, otras_salidas: 0, ajustes: 0, queda: 50, libre: 50 }],
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

  it('pide /informes/stock', () => {
    expect(get).toHaveBeenCalledWith('/informes/stock', expect.anything())
  })

  it('queda por unidad: propio y externo juntos, gramos y unidades separados', () => {
    const kpis = w.findAll('.inf__kpi').map(k => k.text())
    expect(kpis.some(t => t.includes('200 g') && t.includes('Queda (g)'))).toBe(true)
    expect(kpis.some(t => t.includes('12 un') && t.includes('Queda (un)'))).toBe(true)
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
