import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// EL REPROCANN TIENE DOS LECTORES: la nómina para el organismo y LOS PENDIENTES CON NOMBRE para el
// admin (Cumplimiento decía «12 vencidos» y nada más). Las entregas son del período y por unidad,
// y la descarga pide el mismo período que la pantalla.
const apiGet = vi.fn()
vi.mock('../lib/api.js', () => ({ default: { get: (...a) => apiGet(...a) } }))
const descargarArchivo = vi.fn(() => Promise.resolve())
vi.mock('../lib/descargas.js', () => ({ descargarArchivo: (...a) => descargarArchivo(...a) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ error: vi.fn(), success: vi.fn(), info: vi.fn() }) }))
vi.mock('lucide-vue-next', () => ({ FileCheck: { template: '<i />' }, FileDown: { template: '<i />' }, Sheet: { template: '<i />' } }))

const PAYLOAD = {
  resena: 'x', total_pacientes: 3, con_reprocann_vigente: 1, vencen_30d: 1, vencidos: 1, pendientes: 0, sin_reprocann: 0,
  pacientes_sin_registro: 2, periodo: '01/09/2026 — 30/09/2026',
  lista_anonimizada: [
    { nombre_completo: 'Cata Regla', dni_ultimos_3: '333', reprocann_estado: 'vigente', reprocann_vencimiento: '2027-05-01' },
    { nombre_completo: 'Ana Vencida', dni_ultimos_3: '222', reprocann_estado: 'vencido', reprocann_vencimiento: '2026-08-20' },
  ],
  lista_omitidos: 150,
  dispensaciones: { total: 9, por_unidad: [{ unidad: 'g', cantidad: 40 }, { unidad: 'un', cantidad: 3 }], pacientes_atendidos: 3, sin_reprocann_vigente: 1, entregas_sin_vigente: 2 },
  lista_pendientes: [
    { paciente_id: 7, paciente: 'Ana Vencida', dni_ultimos_3: '222', pendiente: 'vencido_retiro', vencimiento: '2026-08-20', dias: -23, ultima_entrega: '2026-09-10' },
    { paciente_id: 8, paciente: 'Beto Pronto', dni_ultimos_3: '444', pendiente: 'por_vencer', vencimiento: '2026-09-24', dias: 12, ultima_entrega: null },
  ],
  pendientes_resumen: { vencido_retiro: 1, por_vencer: 1 },
  cumplimiento: { tasa: 66.7 },
}

describe('REPROCANN — la pantalla muestra lo que el backend manda', () => {
  let wrapper
  beforeEach(async () => {
    vi.clearAllMocks()
    apiGet.mockResolvedValue({ data: PAYLOAD })
    const { default: Vista } = await import('../views/auditor/InformeReprocannView.vue')
    wrapper = mount(Vista, { global: { stubs: { RouterLink: { template: '<a><slot/></a>' } } } })
    await flushPromises()
  })

  it('los pendientes van con nombre, por urgencia, con el DNI en tres dígitos', () => {
    const filas = wrapper.findAll('.inf__section')[1].findAll('tbody tr').map(f => f.text())
    expect(filas[0]).toContain('Venció y sigue retirando')
    expect(filas[0]).toContain('Ana Vencida')
    expect(filas[0]).toContain('···222')
    expect(filas[0]).toContain('hace 23 días')
    expect(filas[1]).toContain('Vence en ≤30 días')
    expect(filas[1]).toContain('en 12 días')
    expect(wrapper.text()).not.toContain('30111')
  })

  it('las entregas son del período, por unidad, y dicen cuántas fueron sin REPROCANN vigente ese día', () => {
    const s = wrapper.findAll('.inf__section')[0].text()
    expect(s).toContain('01/09/2026 — 30/09/2026')
    expect(s).toContain('40 g')
    expect(s).toContain('3 un')
    expect(s).toContain('Entregas sin REPROCANN vigente ese día')
    expect(s).toContain('a 1 paciente')
  })

  it('la nómina incluye a los vencidos y dice cuántos más hay', () => {
    const nom = wrapper.findAll('.inf__section')[2]
    expect(nom.text()).toContain('Ana Vencida')
    expect(nom.text()).toContain('150 pacientes más')
  })

  it('la descarga pide el mismo período que la pantalla', async () => {
    await wrapper.find('.spe__select').setValue('trimestre')
    await flushPromises()
    await wrapper.findAll('.inf__btn')[0].trigger('click')
    expect(descargarArchivo.mock.calls[0][1].params).toMatchObject({ periodo: 'trimestre' })
  })
})
