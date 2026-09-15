import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 15-sep-2026): «al momento de crear una dispensa el modal me ofrece agregar más de
// un ítem; quiero poder hacer lo mismo en la reserva».
//
// Tres cosas: reservando hay botón «Agregar item» y carrito; lo que se manda al backend son las
// LÍNEAS (`items`), no un `stock_id` suelto; y al ENTREGAR una reserva de varios productos se ven
// todos, no sólo el primero.

const SEDE = { id: 10, nombre: 'Central' }

const DEPOSITO = [
  { id: 1, cantidad: 1000, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 1800,
    genetica: { nombre: 'Lemon Cookie' }, fecha_elaboracion: '2026-05-12', sede: SEDE },
  { id: 2, cantidad: 200, unidad: 'un', forma_producto: 'preroll', precio_sugerido_ars: 900,
    genetica: { nombre: 'OG Kush' }, fecha_elaboracion: '2026-05-12', sede: SEDE },
]
const MESA = [
  { stock_id: 1, forma: 'flor_seca', unidad: 'g', genetica: 'Lemon Cookie',
    fecha: '2026-05-12', precio_ars: 1800, mostrador: 110, reservado: 0 },
  { stock_id: 2, forma: 'preroll', unidad: 'un', genetica: 'OG Kush',
    fecha: '2026-05-12', precio_ars: 900, mostrador: 30, reservado: 0 },
]

const listStocks    = vi.fn(() => Promise.resolve({ data: DEPOSITO }))
const getMostrador  = vi.fn(() => Promise.resolve({ data: { mesa: MESA, turno: { id: 1 } } }))
const createReserva = vi.fn(() => Promise.resolve({ data: { id: 77 } }))

vi.mock('../lib/api.js', () => ({
  listStocks:       (...a) => listStocks(...a),
  getMostrador:     (...a) => getMostrador(...a),
  createReserva:    (...a) => createReserva(...a),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  createDispensacion: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

async function montar(props) {
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 1, role: 'admin' }
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, socioId: 5, ...props },
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: true } },
  })
  await flushPromises(); await flushPromises()
  return w
}

async function agregar(w, stockId, cantidad) {
  await w.find(`input.mnd__radio[value="${stockId}"]`).trigger('change')
  const cant = w.findAll('input[type="number"]').find(i => i.attributes('step') === '0.01')
  await cant.setValue(cantidad)
  await w.find('.mnd__add-item').trigger('click')
  await flushPromises()
}

describe('Reservar con carrito', () => {
  beforeEach(() => { createReserva.mockClear() })

  it('ofrece «Agregar item» y arma el carrito con dos productos', async () => {
    const w = await montar({ modoInicial: 'reserva' })

    expect(w.find('.mnd__add-item').exists()).toBe(true)
    await agregar(w, 1, 20)
    await agregar(w, 2, 3)

    const carrito = w.find('.mnd__cart')
    expect(carrito.exists()).toBe(true)
    expect(carrito.text()).toContain('2 productos')
    expect(carrito.text()).toContain('Lemon Cookie')
    expect(carrito.text()).toContain('OG Kush')
    w.unmount()
  })

  it('manda las LÍNEAS al backend, no un producto suelto', async () => {
    const w = await montar({ modoInicial: 'reserva' })
    await agregar(w, 1, 20)
    await agregar(w, 2, 3)
    // El date picker está stubeado: la fecha se escribe directo en el estado del componente.
    w.vm.form.fecha_entrega_estimada = '2099-01-01'
    await w.find('.mnd__btn-primary').trigger('click')
    await flushPromises()

    expect(createReserva).toHaveBeenCalledTimes(1)
    const [pacienteId, payload] = createReserva.mock.calls[0]
    expect(pacienteId).toBe(5)
    expect(payload.items).toEqual([
      { stock_id: 1, cantidad: 20 },
      { stock_id: 2, cantidad: 3 },
    ])
    expect(payload.stock_id).toBeUndefined()
    // El total estimado es la suma de las líneas: 20 × 1800 + 3 × 900.
    expect(Number(payload.aporte_estimado_ars)).toBe(38700)
    w.unmount()
  })

  it('con el carrito vacío no deja crear', async () => {
    const w = await montar({ modoInicial: 'reserva' })
    expect(w.find('.mnd__btn-primary').attributes('disabled')).toBeDefined()
    w.unmount()
  })
})

describe('Entregar una reserva de varios productos', () => {
  const RESERVA = {
    id: 9, estado: 'pendiente', cantidad: 23, sena_ars: 0, aporte_restante_ars: 38700,
    stock: { id: 1, forma_producto: 'flor_seca', unidad: 'g', genetica: 'Lemon Cookie' },
    items: [
      { id: 1, stock_id: 1, cantidad: 20, unidad: 'g',  forma_producto: 'flor_seca', genetica: 'Lemon Cookie', lote: 'L-26-001' },
      { id: 2, stock_id: 2, cantidad: 3,  unidad: 'un', forma_producto: 'preroll',   genetica: 'OG Kush' },
    ],
    paciente: { id: 5, nombre: 'Ana Gómez' },
  }

  it('muestra todas las líneas, no sólo la primera', async () => {
    const w = await montar({ reserva: RESERVA })
    const filas = w.findAll('.mnd__stock-row')
    expect(filas).toHaveLength(2)
    expect(w.text()).toContain('Productos reservados · 2')
    expect(filas[0].text()).toContain('Lemon Cookie')
    expect(filas[0].text()).toContain('20g')
    expect(filas[1].text()).toContain('OG Kush')
    expect(filas[1].text()).toContain('3un')
    // Y no se ofrece elegir producto: ya están definidos.
    expect(w.find('.mnd__add-item').exists()).toBe(false)
    w.unmount()
  })

  it('una reserva vieja, sin líneas, sigue mostrando su producto', async () => {
    const { items, ...vieja } = RESERVA
    const w = await montar({ reserva: vieja })
    const filas = w.findAll('.mnd__stock-row')
    expect(filas).toHaveLength(1)
    expect(filas[0].text()).toContain('Lemon Cookie')
    w.unmount()
  })
})
