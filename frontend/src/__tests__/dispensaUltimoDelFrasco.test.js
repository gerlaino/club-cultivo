import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 1-oct-2026): «al dispensar lo último de un frasco (y que no haya en depósito ni
// nada), en lugar de finalizar directo, un cartel que pregunta: ¿se cierra el frasco?». Si no se
// cierra, queda abierto y vacío para rellenarlo. «Lo último» es el frasco ENTERO (`cantidad_frasco`),
// no lo que está sobre la mesa.
const FLOR = {
  id: 1, cantidad: 10, cantidad_frasco: 10, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 1000,
  numero_lote_producto: 'ST-26-0001', genetica: { id: 1, nombre: 'Lemon' }, sede: { id: 10, nombre: 'Central' },
}
let catalogo = [FLOR]
const createDispensacion = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api.js', () => ({
  listStocks: vi.fn(() => Promise.resolve({ data: catalogo })),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  getMostrador: vi.fn(() => Promise.resolve({ data: { mesa: [], turno: { id: 1 } } })),
  createDispensacion: (...a) => createDispensacion(...a),
  createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }) }))
const confirm = vi.fn()
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm }) }))

const PACIENTE = { id: 5, nombre_completo: 'Ana Gómez', cuenta_corriente: {} }

async function dispensar(cantidad) {
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 1, role: 'admin' }
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, paciente: PACIENTE, socioId: PACIENTE.id },
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: { template: '<a><slot/></a>' } } },
  })
  for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))
  w.vm.form.stock_id = 1
  w.vm.form.cantidad = cantidad
  await w.vm.$nextTick()
  w.vm.agregarItem()
  await w.vm.$nextTick()
  await w.vm.handleSubmit()
  return w
}
const payload = () => createDispensacion.mock.calls.at(-1)?.[1]

describe('Dispensar lo último de un frasco', () => {
  beforeEach(() => { vi.clearAllMocks(); catalogo = [FLOR] })
  afterEach(() => vi.restoreAllMocks())

  it('pregunta, y «Dejarlo abierto» manda el frasco para que quede abierto', async () => {
    confirm.mockResolvedValue('neutral')
    await dispensar(10)
    expect(confirm).toHaveBeenCalledTimes(1)
    expect(confirm.mock.calls[0][0].message).toContain('ST-26-0001')
    expect(confirm.mock.calls[0][0]).toMatchObject({ confirmText: 'Cerrar el frasco', neutralText: 'Dejarlo abierto' })
    expect(payload().dejar_abiertos).toEqual([1])
  })

  it('«Cerrar el frasco»: se dispensa y se cierra como siempre (no viaja nada extra)', async () => {
    confirm.mockResolvedValue(true)
    await dispensar(10)
    expect(payload().dejar_abiertos).toBeUndefined()
  })

  it('«Volver»: no se dispensa', async () => {
    confirm.mockResolvedValue(false)
    await dispensar(10)
    expect(createDispensacion).not.toHaveBeenCalled()
  })

  it('si no se lleva todo el frasco, no pregunta nada', async () => {
    await dispensar(4)
    expect(confirm).not.toHaveBeenCalled()
    expect(createDispensacion).toHaveBeenCalledTimes(1)
  })

  it('en el mostrador cuenta el frasco entero: lo de la mesa no es «lo último» si queda en el depósito', async () => {
    catalogo = [{ ...FLOR, cantidad: 4, cantidad_frasco: 10 }] // 4 sobre la mesa, 6 guardados
    await dispensar(4)
    expect(confirm).not.toHaveBeenCalled()
  })
})
