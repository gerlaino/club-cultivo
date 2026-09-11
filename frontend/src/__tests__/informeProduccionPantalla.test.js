import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// LA PANTALLA DEL INFORME DICE LO MISMO QUE EL ARCHIVO. El backend renombró `gramos` a
// `rendimiento` en el desglose por estado y la pantalla siguió leyendo `gramos`: la columna
// mostraba «—» en todas las filas mientras el PDF del mismo informe traía el número. Y la sección
// «Por sede» estaba en el PDF y el Excel y no en la app. Este test pega el payload REAL del
// controller (mismos nombres de clave) y verifica que la pantalla lo muestre entero.
const apiGet = vi.fn()
vi.mock('../lib/api.js', () => ({ default: { get: (...a) => apiGet(...a) } }))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ error: vi.fn(), success: vi.fn(), info: vi.fn() }),
}))
vi.mock('lucide-vue-next', () => ({ Sprout: { template: '<i />' } }))

// Lo que devuelve `InformesController#produccion` — las claves son las del backend.
const PAYLOAD = {
  resena: 'Cuánto produjo la organización y cómo viene el cultivo.',
  total_lotes: 12, lotes_activos: 9, lotes_cosechados: 3,
  gramos_producidos: 4200.5, plantas_totales: 156,
  por_estado: [
    { estado: 'floracion', lotes: 4, plantas: 120, rendimiento: 0 },
    { estado: 'curado',    lotes: 2, plantas: 0,   rendimiento: 3150.5 },
  ],
  por_sede: [
    { id: 1, nombre: 'Sede Centro', salas: 3, plantas: 156, stock_disponible: 890.0 },
  ],
  total_sedes: 1,
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

  it('el rendimiento acumulado por estado aparece, no «—»', () => {
    const filas = wrapper.findAll('.inf__section').at(0).findAll('tbody tr')
    expect(filas).toHaveLength(2)
    const curado = filas.find(f => f.text().includes('curado'))
    expect(curado.text()).toContain('3.150,5 g')
    expect(curado.text()).not.toContain('—')
  })

  it('la sección Por sede está en la pantalla, no sólo en el archivo', () => {
    const texto = wrapper.text()
    expect(texto).toContain('Por sede')
    expect(texto).toContain('Sede Centro')
    expect(texto).toContain('890 g')
  })

  it('los KPIs se llaman como en el PDF', () => {
    const labels = wrapper.findAll('.inf__kpi-label').map(l => l.text())
    expect(labels).toEqual(['Lotes totales', 'Lotes activos', 'Cosechados', 'Cosechado en el período', 'Plantas en pie'])
  })
})
