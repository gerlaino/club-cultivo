import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// PLAN VS. REAL DIBUJA LO QUE EL BACKEND MANDA (`Informes::PlanVsReal`): gramos Y días contra el plan,
// desvío ponderado pintado sólo fuera de la tolerancia, veredicto por lote, y la ficha de la genética.
const apiGet = vi.fn()
vi.mock('../lib/api.js', () => ({ default: { get: (...a) => apiGet(...a) } }))
vi.mock('../lib/descargas.js', () => ({ descargarArchivo: vi.fn() }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ error: vi.fn(), success: vi.fn(), info: vi.fn() }) }))
vi.mock('lucide-vue-next', () => ({ BarChart2: { template: '<i />' } }))

const PAYLOAD = {
  resena: 'Qué se propuso.',
  tolerancia: { gramos_pct: 10, dias: 7 },
  salio: {
    total: 2, cumplieron: 1, evaluables: 2,
    gramos: { plan: 1000, real: 880, desvio_pct: -12.0, lotes: 2 },
    gramos_por_planta: { plan: 31.7, real: 30.4 },
    floracion: { plan: 56, real: 65, lotes: 2 }, vegetativo: { plan: 28, real: 29, lotes: 2 },
    lotes: [
      { id: 1, codigo: 'L-26-031', genetica: 'Critical', plantas: 18, g_plan: 630, g_real: 612, g_por_planta: 34, vege_plan: 28, vege_real: 30, flora_plan: 56, flora_real: 63, veredicto: 'gramos ✓ · floración ✓', cumplio: true },
      { id: 2, codigo: 'L-26-029', genetica: 'Northern', plantas: 16, g_plan: 560, g_real: 498, g_por_planta: 31.1, vege_plan: 28, vege_real: 27, flora_plan: 60, flora_real: 71, veredicto: '-11.1 % gramos · floración +11 días', cumplio: false },
    ],
  },
  viene: [{ id: 3, codigo: 'L-26-039', genetica: 'Northern', sala: 'Flora 2', estado: 'floracion', dias_plan: 60, dias_hoy: 66, cosecha_planeada: '2026-09-06', pasado_dias: 6, como_viene: '6 días sobre el plan', plantas: 40 }],
  geneticas: [{ genetica: 'Northern', lotes: 4, g_por_planta_ficha: 35, g_por_planta_real: 29.8, floracion_ficha: 60, floracion_real: 70, frase: 'rinde 14.9 % menos que su ficha · tarda 10 días más' }],
}

describe('Plan vs. real — la pantalla muestra lo que el backend manda', () => {
  let wrapper
  beforeEach(async () => {
    vi.clearAllMocks()
    apiGet.mockResolvedValue({ data: PAYLOAD })
    const { default: Vista } = await import('../views/auditor/InformePlanVsRealView.vue')
    wrapper = mount(Vista, { global: { stubs: { RouterLink: true } } })
    await flushPromises()
  })
  const seccion = (n) => wrapper.findAll('.inf__section').at(n)

  it('los KPIs comparan gramos y días, y se pintan sólo fuera de la tolerancia', () => {
    const kpis = seccion(0).findAll('.inf__kpi')
    expect(kpis[0].text()).toContain('▼ 12 %')
    expect(kpis[0].find('.inf__kpi-valor').classes()).toContain('inf__fuera')   // −12 % supera el 10
    expect(kpis[1].text()).toContain('+9 días')
    expect(kpis[1].find('.inf__kpi-valor').classes()).toContain('inf__fuera')   // 9 días supera 7
    expect(kpis[2].find('.inf__kpi-delta').classes()).not.toContain('inf__fuera') // −4 % está adentro
    expect(kpis[3].text()).toContain('1 de 2')
  })

  it('cada lote lleva días plan / real y su veredicto, pintado si no cumplió', () => {
    const filas = seccion(0).findAll('tbody tr')
    expect(filas[1].text()).toContain('60 / 71')
    expect(filas[1].text()).toContain('floración +11 días')
    expect(filas[1].findAll('td')[8].classes()).toContain('inf__mal')
    expect(filas[0].findAll('td')[8].classes()).not.toContain('inf__mal')
  })

  it('«cómo viene» y «qué dice la genética» se dibujan', () => {
    expect(seccion(1).text()).toContain('60 / 66')
    expect(seccion(1).text()).toContain('6 días sobre el plan')
    expect(seccion(2).text()).toContain('rinde 14.9 % menos que su ficha')
  })
})
