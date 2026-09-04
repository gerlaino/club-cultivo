import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC: una dispensa se puede cobrar en varias partes — algo en efectivo, algo en transferencia,
// algo a cuenta corriente.
//
// El backend ya sabía hacerlo: la tabla `cobros` guarda N líneas (medio + monto) y
// `afinar_medio_pago!` marca la dispensa como `mixto` cuando hay más de un medio. Lo usaban las
// entregas del delivery hace rato. Lo que faltaba era la pantalla: el mostrador mandaba UNA sola
// línea sacada de un `<select>`, así que media dispensa en efectivo y media a cuenta no se podía
// cobrar aunque el modelo lo soportara desde siempre.
const SEDE = { id: 10, nombre: 'Central' }
const STOCK = {
  id: 1, cantidad: 500, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 100,
  genetica: { id: 1, nombre: 'Lemon Cookie' }, sede: SEDE,
}

const listStocks = vi.fn(() => Promise.resolve({ data: [STOCK] }))
const createDispensacion = vi.fn(() => Promise.resolve({ data: { id: 99 } }))
vi.mock('../lib/api.js', () => ({
  listStocks: (...a) => listStocks(...a),
  createDispensacion: (...a) => createDispensacion(...a),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  // El carrito pregunta si hay caja abierta cuando lo abre quien atiende el mostrador.
  getMostrador: vi.fn(() => Promise.resolve({ data: { mesa: [], turno: { id: 1 } } })),
  createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
const PACIENTE = { id: 5, nombre_completo: 'Ana Gómez' }

// El crédito entra por PROPS (`limiteCc` / `saldoCc`), no dentro del paciente: la primera
// versión de este test lo puso en `paciente.cuenta_corriente` y `tieneCc` daba false para todos
// los casos, así que dos tests pasaban por la razón equivocada.
async function montar({ limiteCc = 50000, saldoCc = 0 } = {}) {
  setActivePinia(createPinia())
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, paciente: PACIENTE, socioId: PACIENTE.id, limiteCc, saldoCc },
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true } },
  })
  for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))
  return w
}

// Arma el carrito: 50g × $100 = $5.000.
async function conCarrito(w, gramos = 50) {
  w.vm.form.stock_id = STOCK.id
  w.vm.form.cantidad = gramos
  await w.vm.$nextTick()
  w.vm.agregarItem()
  await w.vm.$nextTick()
  return w
}

describe('Dispensar — pago dividido', () => {
  beforeEach(() => vi.clearAllMocks())

  it('no se ofrece dividir en un regalo ni en una reserva: no hay nada que partir', async () => {
    const w = await montar()
    expect(w.vm.puedeDividirPago).toBe(true)

    w.vm.form.es_regalo = true
    await w.vm.$nextTick()
    expect(w.vm.puedeDividirPago).toBe(false)

    w.vm.form.es_regalo = false
    w.vm.form.es_reserva = true
    await w.vm.$nextTick()
    expect(w.vm.puedeDividirPago).toBe(false)
  })

  it('al dividir, arranca con el total puesto y una línea libre para el resto', async () => {
    const w = await montar()
    await conCarrito(w)

    w.vm.activarPagoDividido()
    await w.vm.$nextTick()

    expect(w.vm.lineasPago).toHaveLength(2)
    expect(w.vm.lineasPago[0].monto).toBe(5000)
    // El segundo medio no se repite con el primero.
    expect(w.vm.lineasPago[1].medio).not.toBe(w.vm.lineasPago[0].medio)
  })

  it('un medio por línea: el que ya se usó no se puede volver a elegir', async () => {
    const w = await montar()
    await conCarrito(w)
    w.vm.activarPagoDividido()
    await w.vm.$nextTick()

    const usados = w.vm.lineasPago.map((l) => l.medio)
    expect(w.vm.mediosLibres.map((m) => m.valor)).not.toContain(usados[0])
    expect(w.vm.mediosLibres.map((m) => m.valor)).not.toContain(usados[1])
  })

  it('sin cuenta corriente, ese medio no se ofrece', async () => {
    const w = await montar({ limiteCc: 0 })
    await conCarrito(w)
    w.vm.activarPagoDividido()
    await w.vm.$nextTick()

    expect(w.vm.mediosLibres.map((m) => m.valor)).not.toContain('cuenta_corriente')
  })

  // Lo que falta NO se pierde: el backend lo manda a cuenta corriente. La pantalla lo dice.
  it('avisa cuánto falta y adónde va', async () => {
    const w = await montar()
    await conCarrito(w)
    w.vm.activarPagoDividido()
    w.vm.lineasPago = [{ medio: 'efectivo', monto: 3000 }]
    await w.vm.$nextTick()

    expect(w.vm.restoPago).toBe(2000)
    expect(w.find('.mnd__pagos-resto').text()).toContain('se le cargan a la cuenta corriente')
  })

  it('avisa cuando paga de más: le queda a favor', async () => {
    const w = await montar()
    await conCarrito(w)
    w.vm.activarPagoDividido()
    w.vm.lineasPago = [{ medio: 'efectivo', monto: 6000 }]
    await w.vm.$nextTick()

    expect(w.vm.excedentePago).toBe(1000)
    expect(w.find('.mnd__pagos-resto').text()).toContain('a favor')
  })

  it('manda una línea de cobro por medio, y no un medio_pago único', async () => {
    const w = await montar()
    await conCarrito(w)
    w.vm.activarPagoDividido()
    w.vm.lineasPago = [
      { medio: 'efectivo', monto: 3000 },
      { medio: 'transferencia', monto: 1500 },
      { medio: 'cuenta_corriente', monto: 500 },
    ]
    await w.vm.$nextTick()

    await w.vm.handleSubmit()
    await new Promise((r) => setTimeout(r, 0))

    expect(createDispensacion).toHaveBeenCalled()
    const payload = createDispensacion.mock.calls[0][1]
    expect(payload.cobros).toEqual([
      { medio: 'efectivo', monto: '3000.00' },
      { medio: 'transferencia', monto: '1500.00' },
      { medio: 'cuenta_corriente', monto: '500.00' },
    ])
    // El medio lo deduce el backend de los cobros (`mixto` si hay varios): mandarlo desde acá
    // sería una segunda fuente de verdad para el mismo dato.
    expect(payload.medio_pago).toBeUndefined()
  })

  it('las líneas en cero no viajan', async () => {
    const w = await montar()
    await conCarrito(w)
    w.vm.activarPagoDividido()
    w.vm.lineasPago = [
      { medio: 'efectivo', monto: 5000 },
      { medio: 'transferencia', monto: null },
    ]
    await w.vm.$nextTick()

    await w.vm.handleSubmit()
    await new Promise((r) => setTimeout(r, 0))

    expect(createDispensacion.mock.calls[0][1].cobros).toHaveLength(1)
  })

  // El backend rechazaría igual, pero recién después de mandar: el mostrador se entera tarde.
  it('sin cuenta corriente, no deja dejar plata sin asignar', async () => {
    const w = await montar({ limiteCc: 0 })
    await conCarrito(w)
    w.vm.activarPagoDividido()
    w.vm.lineasPago = [{ medio: 'efectivo', monto: 3000 }]
    await w.vm.$nextTick()

    await w.vm.handleSubmit()
    await new Promise((r) => setTimeout(r, 0))

    expect(createDispensacion).not.toHaveBeenCalled()
    expect(w.vm.formError).toContain('no tiene cuenta corriente')
  })

  it('no deja mandar a cuenta corriente más de lo que hay de crédito', async () => {
    const w = await montar({ limiteCc: 1000 })
    await conCarrito(w)
    w.vm.activarPagoDividido()
    w.vm.lineasPago = [
      { medio: 'efectivo', monto: 1000 },
      { medio: 'cuenta_corriente', monto: 4000 },
    ]
    await w.vm.$nextTick()

    await w.vm.handleSubmit()
    await new Promise((r) => setTimeout(r, 0))

    expect(createDispensacion).not.toHaveBeenCalled()
    expect(w.vm.formError).toContain('crédito disponible')
  })

  // Si deja de aplicar, un desglose invisible no puede seguir viajando.
  it('pasar a regalo apaga el pago dividido', async () => {
    const w = await montar()
    await conCarrito(w)
    w.vm.activarPagoDividido()
    await w.vm.$nextTick()
    expect(w.vm.pagoDividido).toBe(true)

    w.vm.form.es_regalo = true
    await w.vm.$nextTick()
    expect(w.vm.pagoDividido).toBe(false)
  })
})
