import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// LA PANTALLA DEL INFORME DICE LO MISMO QUE EL ARCHIVO. Ya pasó que el backend renombró una clave
// y la pantalla siguió leyendo la vieja: la columna mostraba «—» mientras el PDF del mismo informe
// traía el número. Este test pega el payload REAL de `Informes::Produccion` (mismos nombres de
// clave) y verifica que los tres bloques lo muestren entero.
const apiGet = vi.fn()
vi.mock('../lib/api.js', () => ({ default: { get: (...a) => apiGet(...a) } }))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ error: vi.fn(), success: vi.fn(), info: vi.fn() }),
}))
vi.mock('lucide-vue-next', () => ({ Sprout: { template: '<i />' } }))

const PAYLOAD = {
  resena: 'Qué se cosechó en el período elegido.',
  periodo: {
    lotes: [
      { id: 1, codigo: 'L-26-031', genetica: 'Critical Kush', sede: 'Central', fecha: '2026-09-03',
        plantas: 18, gramos: 612.0, gramos_por_planta: 34.0, dias_ciclo: 98 },
      { id: 2, codigo: 'L-26-034', genetica: 'Gorilla Glue', sede: 'Norte', fecha: '2026-09-08',
        plantas: 15, gramos: null, gramos_por_planta: null, dias_ciclo: 91 },
    ],
    total_lotes: 2, sin_peso: 1, gramos: 612.0, plantas: 18, gramos_por_planta: 34.0,
    anterior: { total_lotes: 1, sin_peso: 0, gramos: 500.0, plantas: 20, gramos_por_planta: 25.0 },
    variacion: { gramos: 22.4, total_lotes: 100.0, plantas: -10.0, gramos_por_planta: 36.0 },
  },
  hoy: {
    plantas_en_pie: 312, lotes_en_pie: 2, lotes_en_proceso: 2,
    por_estado: [
      { estado: 'floracion', lotes: 2, plantas: 110, dias_promedio: 41,
        mas_viejo: { codigo: 'L-26-038', dias: 80, objetivo: 60, excedido: true }, rendimiento: 0 },
      { estado: 'cosecha', lotes: 1, plantas: 24, dias_promedio: 4,
        mas_viejo: { codigo: 'L-26-035', dias: 4, objetivo: null, excedido: false }, rendimiento: 0 },
      { estado: 'curado', lotes: 1, plantas: null, dias_promedio: 19,
        mas_viejo: { codigo: 'L-26-029', dias: 19, objetivo: null, excedido: false }, rendimiento: 3150.5 },
    ],
    plan: { label: 'Básico', tope: 450, cuentan: 312 },
  },
  por_sede: [{ id: 1, nombre: 'Sede Centro', salas: 3, plantas: 312, stock_disponible: 890.0 }],
  proximas: [
    { id: 5, codigo: 'L-26-038', genetica: 'Critical Kush', sala: 'Flora 1', plantas: 36,
      fecha: '2026-09-24', dias: 12, gramos_por_planta_ref: 34.0, estimado: 1224 },
    { id: 6, codigo: 'L-26-041', genetica: 'Nueva', sala: 'Flora 2', plantas: 10,
      fecha: null, dias: null, gramos_por_planta_ref: null, estimado: null },
  ],
}

describe('Informe de Producción — la pantalla muestra lo que el backend manda', () => {
  let wrapper

  beforeEach(async () => {
    vi.clearAllMocks()
    apiGet.mockResolvedValue({ data: PAYLOAD })
    const { default: Vista } = await import('../views/auditor/InformeProduccionView.vue')
    wrapper = mount(Vista, { global: { stubs: { RouterLink: true } } })
    await flushPromises()
  })

  const seccion = (n) => wrapper.findAll('.inf__section').at(n)

  it('los KPIs del período se llaman como en el PDF y llevan la comparación', () => {
    const labels = seccion(0).findAll('.inf__kpi-label').map(l => l.text())
    expect(labels).toEqual(['Flor seca cosechada', 'Lotes cosechados', 'Por planta cosechada', 'Plantas cosechadas'])
    const deltas = seccion(0).findAll('.inf__kpi-delta').map(d => d.text())
    expect(deltas[0]).toBe('▲ 22.4 % vs. anterior (500 g)')
    expect(deltas[2]).toBe('▲ 36 % vs. anterior (25 g)')
  })

  it('lista los lotes cosechados y dice cuál no tiene peso todavía', () => {
    const filas = seccion(0).findAll('tbody tr')
    expect(filas).toHaveLength(2)
    expect(filas[0].text()).toContain('612 g')
    expect(filas[1].text()).toContain('sin peso todavía')
    expect(seccion(0).text()).toContain('Un lote todavía no tiene peso')
  })

  it('el rendimiento acumulado por etapa aparece, y el más viejo se marca sólo si excede el objetivo', () => {
    const filas = seccion(1).findAll('tbody tr')
    expect(filas[2].text()).toContain('3.150,5 g')
    expect(filas[0].find('.inf__excedido').exists()).toBe(true)
    expect(filas[0].find('.inf__excedido').text()).toBe('objetivo 60')
    expect(filas[2].find('.inf__excedido').exists()).toBe(false)
  })

  // Las plantas cortadas siguen siendo plantas mientras cuelgan (cosecha) y se pesan (manicura);
  // en curado ya es flor en frasco y la celda va vacía, no en cero.
  it('la etapa cosecha muestra sus plantas y curado no', () => {
    const celdas = seccion(1).findAll('tbody tr').map(f => f.findAll('td')[2].text())
    expect(celdas).toEqual(['110', '24', '—'])
    const labels = seccion(1).findAll('.inf__kpi-label').map(l => l.text())
    expect(labels).toEqual(['Plantas en cultivo', 'Lotes en cultivo', 'Lotes cosechados'])
  })

  it('la ocupación contra el plan sale sólo si hay tope', async () => {
    expect(seccion(1).text()).toContain('312 de 450 del plan Básico · 69 %')

    apiGet.mockResolvedValue({ data: { ...PAYLOAD, hoy: { ...PAYLOAD.hoy, plan: null } } })
    await wrapper.find('.spe__select').trigger('change')
    await flushPromises()
    expect(wrapper.text()).not.toContain('del plan')
  })

  it('lo que viene estima con la historia y lo dice cuando no la hay', () => {
    const filas = seccion(2).findAll('tbody tr')
    expect(filas[0].text()).toContain('en 12 días')
    expect(filas[0].text()).toContain('≈ 1.224 g')
    expect(filas[1].text()).toContain('sin fecha')
    expect(filas[1].text()).toContain('sin historia para estimar')
  })

  it('la sección Por sede está en la pantalla, no sólo en el archivo', () => {
    const texto = seccion(3).text()
    expect(texto).toContain('Sede Centro')
    expect(texto).toContain('890 g')
  })
})
