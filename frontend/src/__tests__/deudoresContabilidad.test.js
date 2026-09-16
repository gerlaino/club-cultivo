import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 16-sep-2026): el KPI «Por cobrar» lleva a la solapa Deudores, con la lista completa
// de pacientes con cuenta corriente, ordenable por mayor deudor y con buscador por paciente.
const CUENTAS = {
  total_deuda: 21500, deudores: 2,
  cuentas: [
    { paciente_id: 2, nombre: 'Grande Test', dni: '20000002', activo: true,  saldo: -20000, deuda: 20000, limite: 50000, porcentaje_limite: 40, ultimo_movimiento: '2026-09-10T12:00:00Z' },
    { paciente_id: 1, nombre: 'Chico Test',  dni: '20000001', activo: true,  saldo: -1500,  deuda: 1500,  limite: 0,     porcentaje_limite: 0,  ultimo_movimiento: null },
    { paciente_id: 3, nombre: 'AFavor Test', dni: '20000003', activo: false, saldo: 3000,   deuda: 0,     limite: 10000, porcentaje_limite: 0,  ultimo_movimiento: null },
  ],
}
const listCuentasCorrientes = vi.fn(() => Promise.resolve({ data: CUENTAS }))
const push = vi.fn()

vi.mock('../lib/api.js', () => ({ default: { get: vi.fn(), post: vi.fn() } }))
vi.mock('../lib/api', () => ({
  default: { get: vi.fn(() => Promise.resolve({ data: {} })), post: vi.fn() },
  listCuentasCorrientes: (...a) => listCuentasCorrientes(...a),
  // El KPI se dibuja con lo que trae el dashboard: es lo que hace clickeable el número.
  getContableDashboard: vi.fn(() => Promise.resolve({ data: { por_cobrar: 21500, mes_actual: { ingresos: 0, egresos: 0, balance: 0, por_mes: [] }, anio_actual: { balance: 0, por_mes: [] }, por_sede: [], por_unidad: [], ultimos_movimientos: [] } })),
  listRetirosCaja: vi.fn(() => Promise.resolve({ data: { por_persona: [], saldados: [], total_abierto: 0 } })),
  saldarRetiroCaja: vi.fn(),
  listSedes: vi.fn(() => Promise.resolve({ data: [] })), listLotes: vi.fn(() => Promise.resolve({ data: [] })),
  listPacientes: vi.fn(() => Promise.resolve({ data: { data: [] } })), cerrarPeriodoContable: vi.fn(),
  reabrirPeriodoContable: vi.fn(), createCompraCuotas: vi.fn(),
  listComprasCuotas: vi.fn(() => Promise.resolve({ data: [] })),
  listUnidadesNegocio: vi.fn(() => Promise.resolve({ data: [] })),
  listInsumos: vi.fn(() => Promise.resolve({ data: [] })), listBares: vi.fn(() => Promise.resolve({ data: [] })),
  listCategoriasContables: vi.fn(() => Promise.resolve({ data: [] })),
  listDepositos: vi.fn(() => Promise.resolve({ data: [] })), registrarPagoMovimiento: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }) }))
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: {}, params: {}, path: '/contabilidad' }),
  useRouter: () => ({ push, replace: vi.fn() }),
}))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn(() => Promise.resolve(true)) }) }))

async function montar () {
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth')
  useAuthStore().user = { id: 1, role: 'admin', first_name: 'German' }
  const { default: V } = await import('../views/ContabilidadView.vue')
  const w = mount(V, { global: { stubs: { RouterLink: true, AppDatePicker: true, DsSpinner: true,
    GastosRecurrentesView: true, ModalIngreso: true, ModalMovimiento: true,
    EditarCompraCuotasModal: true, Teleport: true } } })
  await flushPromises()
  return w
}

function nombres (w) {
  return w.findAll('.cv__deu-row').map(r => r.find('.cv__td-bold').text())
}

describe('Contabilidad → Deudores', () => {
  beforeEach(() => vi.clearAllMocks())

  it('el KPI «Por cobrar» lleva a la solapa, con la lista mayor deudor primero', async () => {
    const w = await montar()
    await w.find('.cv__kpi--link').trigger('click')
    await flushPromises()

    expect(listCuentasCorrientes).toHaveBeenCalled()
    expect(w.vm.vistaActiva).toBe('deudores')
    expect(w.text()).toContain('deben 2 pacientes')
    // «Sólo con deuda» viene prendido: el que tiene saldo a favor no aparece.
    expect(nombres(w)).toEqual(['Grande Test', 'Chico Test'])
  })

  it('se ordena por columna: por nombre, y de vuelta por deuda invirtiendo', async () => {
    const w = await montar()
    w.vm.irADeudores(); await flushPromises()

    w.vm.ordenarDeudoresPor('nombre'); await w.vm.$nextTick()
    expect(nombres(w)).toEqual(['Chico Test', 'Grande Test'])

    w.vm.ordenarDeudoresPor('deuda'); await w.vm.$nextTick()   // desc
    expect(nombres(w)).toEqual(['Grande Test', 'Chico Test'])
    w.vm.ordenarDeudoresPor('deuda'); await w.vm.$nextTick()   // asc
    expect(nombres(w)).toEqual(['Chico Test', 'Grande Test'])
  })

  it('busca por nombre o DNI', async () => {
    const w = await montar()
    w.vm.irADeudores(); await flushPromises()

    w.vm.deudoresBusqueda = 'chic'; await w.vm.$nextTick()
    expect(nombres(w)).toEqual(['Chico Test'])

    w.vm.deudoresBusqueda = '20000002'; await w.vm.$nextTick()
    expect(nombres(w)).toEqual(['Grande Test'])
  })

  it('apagando «Sólo con deuda» aparece la lista completa, con el saldo a favor y la baja', async () => {
    const w = await montar()
    w.vm.irADeudores(); await flushPromises()

    w.vm.deudoresSoloConDeuda = false; await w.vm.$nextTick()
    expect(nombres(w)).toEqual(['Grande Test', 'Chico Test', 'AFavor Test'])
    expect(w.text()).toContain('a favor')
    expect(w.text()).toContain('dado de baja')
  })

  it('cada fila lleva a la cuenta corriente del paciente', async () => {
    const w = await montar()
    w.vm.irADeudores(); await flushPromises()

    await w.find('.cv__deu-row').trigger('click')
    expect(push).toHaveBeenCalledWith({ path: '/pacientes/2', query: { tab: 'cuenta_corriente' } })
  })
})
