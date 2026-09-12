import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// LA PANTALLA DE PÉRDIDAS MUESTRA LO QUE EL BACKEND MANDA, con el payload real de `Informes::Perdidas`:
// dos bloques, cada unidad en lo suyo, la plata al lado («producirlo costó»), y subir es malo.
const apiGet = vi.fn()
vi.mock('../lib/api.js', () => ({ default: { get: (...a) => apiGet(...a) } }))
vi.mock('../lib/descargas.js', () => ({ descargarArchivo: vi.fn() }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ error: vi.fn(), success: vi.fn(), info: vi.fn() }) }))
vi.mock('lucide-vue-next', () => ({ TrendingDown: { template: '<i />' } }))

const PAYLOAD = {
  resena: 'Qué se perdió.',
  plantas: {
    total: 7, anterior: 10, en_cultivo: 323, porcentaje: 2.1, costo_ars: 41300, sin_costo: 0,
    por_motivo: [{ motivo: 'macho', plantas: 3, lotes: [{ codigo: 'L-26-038', plantas: 2 }, { codigo: 'L-26-041', plantas: 1 }], ultima: '2026-08-23' }],
    lista: [{ id: 1, nombre: 'L-26-038-P004', lote: 'L-26-038', genetica: 'Critical', motivo: 'macho', fecha: '2026-08-23', fecha_estimada: false, costo_ars: 5900 }],
    omitidas: 0,
  },
  producto: {
    por_unidad: [{ unidad: 'g', cantidad: 38, anterior: 26 }, { unidad: 'un', cantidad: 4, anterior: 4 }],
    merma_por_unidad: [{ unidad: 'g', cantidad: 2 }], mostrador_por_unidad: [{ unidad: 'g', cantidad: 36 }],
    costo_ars: 21400, sin_costo: 0,
    lista: [
      { frasco: 'ST-26-041', genetica: 'Critical', forma: 'flor_seca', unidad: 'g', que_paso: 'Diferencias de conteo del mostrador, 9 cierres (neto)', detalle: null, fecha: '2026-08-30', mostrador: true, cantidad: 31, costo_ars: 15500 },
      { frasco: 'ST-26-041', genetica: 'Critical', forma: 'flor_seca', unidad: 'g', que_paso: 'Merma declarada', detalle: 'se cayó el frasco', fecha: '2026-08-22', mostrador: false, cantidad: 2, costo_ars: 1000 },
    ],
    omitidas: 0,
  },
}

describe('Informe de Pérdidas — la pantalla muestra lo que el backend manda', () => {
  let wrapper
  beforeEach(async () => {
    vi.clearAllMocks()
    apiGet.mockResolvedValue({ data: PAYLOAD })
    const { default: Vista } = await import('../views/auditor/InformePerdidasView.vue')
    wrapper = mount(Vista, { global: { stubs: { RouterLink: { template: '<a><slot/></a>' } } } })
    await flushPromises()
  })
  const seccion = (n) => wrapper.findAll('.inf__section').at(n)

  it('las plantas: menos que el anterior es verde, y el motivo lleva el lote', () => {
    const kpis = seccion(0).findAll('.inf__kpi').map(k => k.text())
    expect(kpis[0]).toContain('▼ 3 vs. anterior (10)')
    expect(seccion(0).findAll('.inf__kpi-delta')[0].classes()).toContain('inf__kpi-delta--up')
    expect(kpis[2]).toContain('$ 41.300')
    expect(seccion(0).find('tbody tr').text()).toContain('L-26-038 (2) · L-26-041')
  })

  it('el producto va por unidad, subir es ámbar, y la diferencia del mostrador se dice con su link', () => {
    const kpis = seccion(1).findAll('.inf__kpi').map(k => k.text())
    expect(kpis[0]).toContain('38 g')
    expect(kpis[0]).toContain('▲ 12 g vs. anterior (26 g)')
    expect(seccion(1).findAll('.inf__kpi-delta')[0].classes()).toContain('inf__kpi-delta--down')
    expect(kpis[1]).toContain('4 un')
    expect(seccion(1).find('.inf__nota').text()).toContain('36 g son diferencias de conteo del mostrador')
    const filas = seccion(1).findAll('tbody tr').map(f => f.text())
    expect(filas[1]).toContain('«se cayó el frasco»')
    expect(filas[1]).toContain('$ 1.000')
  })

  it('no hay stock vencido: no existe', () => {
    expect(wrapper.text()).not.toMatch(/vencid/i)
  })
})
