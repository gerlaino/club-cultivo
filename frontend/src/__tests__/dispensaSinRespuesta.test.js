import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// "SIN CONEXIÓN" Y "NO CONTESTÓ A TIEMPO" NO SON LO MISMO.
//
// Los dos llegan al frontend igual (sin `response`), pero significan cosas opuestas:
//   · sin señal      → el pedido nunca salió: la dispensa NO existe, reintentar es correcto;
//   · timeout (10 s) → el pedido SALIÓ y no sabemos qué pasó: puede haber entrado perfecta.
//
// Decirle "no se registró, volvé a intentar" en el segundo caso es pedirle que duplique una
// venta: el mismo gramo afuera dos veces y el doble de plata en el arqueo. Es el único lugar de
// la app donde una mentira piadosa cuesta inventario.
const UNA_SEDE = { id: 10, nombre: 'Central' }
const FLOR = {
  id: 1, cantidad: 300, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 1800,
  genetica: { id: 1, nombre: 'Lemon Cookie' }, fecha_elaboracion: '2026-01-10', sede: UNA_SEDE,
}

const createDispensacion = vi.fn()
vi.mock('../lib/api.js', () => ({
  listStocks: vi.fn(() => Promise.resolve({ data: [FLOR] })),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  getMostrador: vi.fn(() => Promise.resolve({ data: { mesa: [], turno: { id: 1 } } })),
  createDispensacion: (...a) => createDispensacion(...a),
  createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
const toastError = vi.fn()
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: toastError, warning: vi.fn(), info: vi.fn() }),
}))

const PACIENTE = { id: 5, nombre_completo: 'Ana Gómez', cuenta_corriente: {} }

async function dispensar (error, { online = true } = {}) {
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 1, role: 'admin' }
  vi.spyOn(navigator, 'onLine', 'get').mockReturnValue(online)
  createDispensacion.mockRejectedValueOnce(error)

  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, paciente: PACIENTE, socioId: PACIENTE.id },
    global: {
      stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true,
               RouterLink: { template: '<a><slot/></a>' } },
    },
  })
  for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))

  w.vm.form.stock_id = 1
  w.vm.form.cantidad = 10
  await w.vm.$nextTick()
  w.vm.agregarItem()
  await w.vm.$nextTick()
  await w.vm.handleSubmit()
  return w
}

describe('cuando el servidor no contesta', () => {
  beforeEach(() => vi.clearAllMocks())
  afterEach(() => vi.restoreAllMocks())

  it('por timeout, avisa que PUEDE haber entrado y manda a mirar el historial', async () => {
    const w = await dispensar({ code: 'ECONNABORTED', message: 'timeout of 10000ms exceeded' })

    expect(w.vm.formError).toContain('PUEDE haber quedado registrada')
    expect(w.vm.formError).toContain('historial')
    expect(w.vm.formError).not.toContain('NO se registró')
  })

  // Con el teléfono conectado, un error sin respuesta es lo mismo: salió y no sabemos.
  it('con red pero sin respuesta, tampoco afirma que no entró', async () => {
    const w = await dispensar(new Error('Network Error'), { online: true })

    expect(w.vm.formError).toContain('PUEDE haber quedado registrada')
  })

  // Sin señal el pedido nunca salió: ahí sí se puede afirmar, y reintentar es lo correcto.
  it('sin señal, dice que NO se registró y que reintente', async () => {
    const w = await dispensar(new Error('Network Error'), { online: false })

    expect(w.vm.formError).toContain('NO se registró')
    expect(w.vm.formError).toContain('volvé a intentar')
  })

  // Un rechazo del backend es otra cosa: hay respuesta y hay motivo.
  it('si el backend rechaza, muestra su motivo', async () => {
    const w = await dispensar({ response: { data: { error: 'Stock insuficiente' } } })

    expect(w.vm.formError).toBe('Stock insuficiente')
  })
})
