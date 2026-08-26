import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC: el admin ve cuánto le debe cada uno y lo cierra eligiendo QUÉ fue ese retiro.
const RETIROS = {
  total_abierto: 130000,
  por_persona: [{ user_id: 1, nombre: 'German Laino', rol: 'admin', debe: 130000, retiros: [
    { id: 9, fecha: '2026-08-26', monto_ars: 100000, descripcion: 'Retiro de caja — proveedor', retirado_por: 'German Laino' },
    { id: 8, fecha: '2026-08-24', monto_ars: 30000, descripcion: 'Retiro de caja — adelanto', retirado_por: 'German Laino' },
  ] }],
  saldados: [],
}
const saldarRetiroCaja = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api.js', () => ({ default: { get: vi.fn(), post: vi.fn() } }))
vi.mock('../lib/api', () => ({
  default: { get: vi.fn(() => Promise.resolve({ data: {} })), post: vi.fn() },
  listRetirosCaja: vi.fn(() => Promise.resolve({ data: RETIROS })),
  saldarRetiroCaja: (...a) => saldarRetiroCaja(...a),
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
// Sin esto la vista lee `route.query` de un undefined y deja errores sin manejar: los tests
// pasan igual, pero vitest avisa que puede haber falsos positivos.
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: {}, params: {}, path: '/contabilidad' }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn(() => Promise.resolve(true)) }) }))

describe('Retiros de caja — saldar', () => {
  beforeEach(() => vi.clearAllMocks())

  async function abrirTab() {
    setActivePinia(createPinia())
    const { useAuthStore } = await import('../stores/auth')
    useAuthStore().user = { id: 1, role: 'admin', first_name: 'German' }
    const { default: V } = await import('../views/ContabilidadView.vue')
    const w = mount(V, { global: { stubs: { RouterLink: true, AppDatePicker: true, DsSpinner: true,
      GastosRecurrentesView: true, ModalIngreso: true, ModalMovimiento: true,
      EditarCompraCuotasModal: true, Teleport: true } } })
    for (let i = 0; i < 8; i++) await new Promise((r) => setTimeout(r, 0))
    w.vm.irARetiros()
    for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))
    return w
  }

  it('muestra cuánto debe cada uno, sumando sus retiros abiertos', async () => {
    const w = await abrirTab()
    expect(w.text()).toContain('German Laino')
    expect(w.find('.cv__ret-debe').text()).toContain('130')
  })

  it('al saldar elige QUÉ fue el retiro, y con comprobante pide categoría', async () => {
    const w = await abrirTab()
    await w.findAll('.cv__ret-btn')[0].trigger('click')
    expect(w.text()).toContain('Devolvió la plata')
    expect(w.text()).toContain('Trajo comprobante')
    expect(w.text()).toContain('Se descuenta del sueldo')

    w.vm.formaSaldo = 'comprobante'
    await w.vm.$nextTick()
    expect(w.find('.cv__ret-extra').exists()).toBe(true)

    w.vm.categoriaSaldo = 'insumo'
    await w.vm.$nextTick()
    await w.vm.confirmarSaldar()
    expect(saldarRetiroCaja).toHaveBeenCalledWith(9, expect.objectContaining({ forma: 'comprobante', categoria: 'insumo' }))
  })
})
