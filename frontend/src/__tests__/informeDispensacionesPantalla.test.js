import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// LA PANTALLA DEL INFORME DICE LO MISMO QUE EL ARCHIVO. Pega el payload REAL de
// `Informes::Dispensaciones` (mismos nombres de clave) y fija: cada unidad en lo suyo, los regalos
// dichos aparte, la tabla de producto forma × genética, el DNI en tres dígitos, «y N más», y que
// la DESCARGA pide el mismo período que la pantalla (antes bajaba siempre «mes actual»).
const apiGet = vi.fn()
vi.mock('../lib/api.js', () => ({ default: { get: (...a) => apiGet(...a) } }))
const descargarArchivo = vi.fn(() => Promise.resolve())
vi.mock('../lib/descargas.js', () => ({ descargarArchivo: (...a) => descargarArchivo(...a) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ error: vi.fn(), success: vi.fn(), info: vi.fn() }) }))
vi.mock('lucide-vue-next', () => ({ Package: { template: '<i />' } }))

const PAYLOAD = {
  resena: 'Qué salió de la organización.',
  salio: {
    por_unidad: [{ unidad: 'g', cantidad: 2148, anterior: 1970, variacion: 9.0 }, { unidad: 'un', cantidad: 312, anterior: null, variacion: null }],
    entregas: { valor: 418, anterior: 402, variacion: 4.0 },
    pacientes: { valor: 137, anterior: 120 },
    nuevos: 11,
    regalos: [{ unidad: 'g', cantidad: 14 }], regalos_entregas: 3,
  },
  productos: [
    { forma: 'flor_seca', unidad: 'g', entregas: 300, cantidad: 2148, pacientes: 120,
      geneticas: [{ genetica: 'Critical Kush', entregas: 164, cantidad: 892, pacientes: 71, anterior: 780, variacion: 14.4 }] },
    { forma: 'preroll', unidad: 'un', entregas: 88, cantidad: 312, pacientes: 39,
      geneticas: [{ genetica: 'Critical Kush', entregas: 88, cantidad: 312, pacientes: 39, anterior: 332, variacion: -6.0 }] },
  ],
  pacientes: [
    { paciente: 'María Fernández', dni_ultimos_3: '412', entregas: 9, flor_seca_g: 62, por_unidad: [], otros: [{ forma: 'preroll', unidad: 'un', cantidad: 6 }], geneticas: ['Critical Kush'], formas: ['flor_seca', 'preroll'], ultima_fecha: '2026-08-29' },
  ],
  pacientes_omitidos: 134,
  canales: [
    { canal: 'Mostrador · Central', entregas: 286, pacientes: 104, flor_seca_g: 1510, por_unidad: [], otros: [] },
    { canal: 'Envío a domicilio', entregas: 61, pacientes: 31, flor_seca_g: 300, por_unidad: [], otros: [], sin_llegar: 4 },
  ],
}

describe('Informe de Dispensaciones — la pantalla muestra lo que el backend manda', () => {
  let wrapper

  beforeEach(async () => {
    vi.clearAllMocks()
    apiGet.mockResolvedValue({ data: PAYLOAD })
    const { default: Vista } = await import('../views/auditor/InformeDispensacionesView.vue')
    wrapper = mount(Vista, { global: { stubs: { RouterLink: true } } })
    await flushPromises()
  })

  const seccion = (n) => wrapper.findAll('.inf__section').at(n)

  it('cada unidad en lo suyo, con la comparación, y los regalos dichos aparte', () => {
    const kpis = seccion(0).findAll('.inf__kpi').map(k => k.text())
    expect(kpis[0]).toContain('2.148 g')
    expect(kpis[0]).toContain('▲ 9 % vs. anterior (1.970 g)')
    expect(kpis[1]).toContain('312 un')
    expect(kpis[1]).toContain('sin datos del período anterior')
    expect(kpis[3]).toContain('11 retiraron por primera vez')
    expect(seccion(0).find('.inf__nota').text()).toBe('De eso, 14 g fueron regalos, en 3 entregas.')
  })

  it('la tabla de producto es forma × genética, con la variación por genética', () => {
    const filas = seccion(0).findAll('tbody tr').map(f => f.text())
    expect(filas[0]).toContain('Flor seca')
    expect(filas[1]).toContain('Critical Kush')
    expect(filas[1]).toContain('▲ 14.4 %')
    expect(filas[3]).toContain('▼ 6 %')
  })

  it('el paciente lleva tres dígitos del DNI, los otros productos con su unidad, y se dice cuántos más hay', () => {
    const fila = seccion(1).find('tbody tr').text()
    expect(fila).toContain('···412')
    expect(fila).toContain('62 g')
    expect(fila).toContain('6 un preroll')
    expect(seccion(1).find('.inf__mas').text()).toContain('134 pacientes más')
    expect(wrapper.text()).not.toContain('30111')
  })

  it('el envío dice cuántos no llegaron todavía', () => {
    expect(seccion(2).text()).toContain('4 sin llegar todavía')
  })

  it('la descarga pide el MISMO período que la pantalla', async () => {
    const sel = wrapper.find('.spe__select')
    await sel.setValue('trimestre')
    await flushPromises()
    expect(apiGet).toHaveBeenLastCalledWith('/informes/dispensaciones', { params: { periodo: 'trimestre' } })

    await wrapper.findAll('.inf__pdf')[0].trigger('click')
    expect(descargarArchivo.mock.calls[0][1].params).toEqual({ periodo: 'trimestre' })
  })

  it('el rango a elección manda desde y hasta', async () => {
    await wrapper.find('.spe__select').setValue('rango')
    await wrapper.findAll('.spe__fecha')[0].setValue('2026-08-01')
    await wrapper.findAll('.spe__fecha')[1].setValue('2026-08-15')
    await flushPromises()
    expect(apiGet).toHaveBeenLastCalledWith('/informes/dispensaciones', { params: { desde: '2026-08-01', hasta: '2026-08-15' } })
  })
})
