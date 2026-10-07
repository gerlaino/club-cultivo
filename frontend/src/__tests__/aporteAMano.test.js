import { describe, it, expect, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { vModal } from '../directives/modal.js'

// AC (7-oct-2026, reemplaza al del 5-oct): EL TOTAL NO SE TIPEA. Es la suma del carrito menos los
// descuentos; para cobrar menos hay descuento en % o en PESOS, y lo que se ve es lo que se cobra.
// El caso que originó todo sigue cubierto: $60.000 de productos cobrados $22.000 = descuento de
// $38.000, a la vista.

const STOCK = {
  id: 1, cantidad: 500, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 12000,
  genetica: { id: 1, nombre: 'Blue Sherbet' }, sede: { id: 10, nombre: 'Central' },
}
vi.mock('../lib/api.js', () => ({
  listStocks: vi.fn(() => Promise.resolve({ data: [STOCK] })),
  createDispensacion: vi.fn(() => Promise.resolve({ data: { id: 99 } })),
  updateDispensacion: vi.fn(() => Promise.resolve({ data: {} })),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  getMostrador: vi.fn(() => Promise.resolve({ data: { mesa: [], turno: { id: 1 } } })),
  createReserva: vi.fn(), entregarReserva: vi.fn(), agregarEnvioDispensacion: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
const { useAuthStore } = await import('../stores/auth')

const filaTotal = w => w.findAll('.mnd__precio-row--total').map(r => r.text()).join(' ')

describe('Nueva dispensa — el total no se tipea', () => {
  async function montar() {
    setActivePinia(createPinia())
    useAuthStore().user = { role: 'admin' }
    const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
    const w = mount(Modal, {
      props: { modelValue: true, paciente: { id: 5, nombre_completo: 'Martín Blanco' }, socioId: 5, limiteCc: 50000, saldoCc: 0 },
      global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: true } },
    })
    for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))
    w.vm.form.stock_id = STOCK.id
    w.vm.form.cantidad = 5                                   // 5g × $12.000 = $60.000
    await w.vm.$nextTick()
    w.vm.agregarItem()
    await w.vm.$nextTick()
    return w
  }

  it('sin descuento, el total es el de los productos y no hay campo para tipearlo', async () => {
    const w = await montar()
    expect(filaTotal(w)).toContain('60.000')
    expect(w.text()).not.toContain('Precio total')
    expect(w.text()).not.toContain('editable')
  })

  it('con descuento en pesos, el total es la suma menos el descuento, y el descuento se ve', async () => {
    const w = await montar()
    w.vm.form.descuento_modo = 'ars'
    w.vm.form.descuento_ars = 38000
    await w.vm.$nextTick()
    expect(filaTotal(w)).toContain('22.000')
    expect(w.text()).toContain('Descuento esta dispensa')
    expect(w.text()).toContain('38.000')
    expect(w.vm.totalACobrar).toBe(22000)                    // lo que se ve es lo que se cobra
  })

  it('manda el descuento en pesos y NO un total', async () => {
    const { createDispensacion } = await import('../lib/api.js')
    createDispensacion.mockClear()
    const w = await montar()
    w.vm.form.descuento_modo = 'ars'
    w.vm.form.descuento_ars = 38000
    await w.vm.$nextTick()
    await w.vm.handleSubmit()
    expect(createDispensacion).toHaveBeenCalled()
    const payload = createDispensacion.mock.calls[0][1]
    expect(payload.aporte_socio_ars).toBeUndefined()
    expect(payload.descuento_dispensa_ars).toBe('38000.00')
  })

  it('un descuento que se come todo avisa que es un regalo', async () => {
    const w = await montar()
    w.vm.form.descuento_modo = 'ars'
    w.vm.form.descuento_ars = 60000
    await w.vm.$nextTick()
    expect(w.text()).toContain('Regalo')
  })

  it('en %, el de pesos no viaja (uno u otro)', async () => {
    const w = await montar()
    w.vm.form.descuento_ars = 5000                           // quedó escrito, pero el modo es %
    w.vm.form.descuento_pct = 10
    await w.vm.$nextTick()
    expect(filaTotal(w)).toContain('54.000')
  })
})

describe('Editar dispensa — el total no se tipea', () => {
  // La dispensa de la #838, anterior al 7-oct: líneas que suman $171.000, total cobrado $80.000.
  const DISPENSA = {
    id: 90, paciente_nombre: 'Martín Blanco', cantidad: 16, aporte_socio_ars: 80000, subtotal_productos_ars: 80000,
    fecha_dispensacion: '2026-10-05', medio_pago: 'efectivo', observaciones: '',
    items: [
      { id: 1, stock_id: 5, cantidad: 8, precio_unitario_ars: 10500, stock: { id: 5, forma_producto: 'flor_seca', unidad: 'g' } },
      { id: 2, stock_id: 6, cantidad: 2, precio_unitario_ars: 12000, stock: { id: 6, forma_producto: 'flor_seca', unidad: 'g' } },
      { id: 3, stock_id: 7, cantidad: 3, precio_unitario_ars: 10500, stock: { id: 7, forma_producto: 'flor_seca', unidad: 'g' } },
      { id: 4, stock_id: 8, cantidad: 3, precio_unitario_ars: 10500, stock: { id: 8, forma_producto: 'flor_seca', unidad: 'g' } },
    ],
    paciente_saldo_cc: 0, paciente_limite_cc: 0,
  }
  async function montar(role) {
    setActivePinia(createPinia())
    useAuthStore().user = { role }
    const Modal = (await import('../components/pacientes/ModalEditarDispensacion.vue')).default
    const w = mount(Modal, {
      props: { modelValue: true, dispensacion: DISPENSA },
      global: { stubs: { Teleport: true, AppDatePicker: true, DsSpinner: true }, directives: { modal: vModal } },
    })
    await flushPromises()
    return w
  }

  it('una vieja con el total pisado abre con la diferencia como descuento: el precio no cambia', async () => {
    const w = await montar('admin')
    expect(w.text()).toContain('171.000')
    expect(w.text()).toContain('Descuento')
    expect(w.text()).toContain('91.000')
    expect(w.vm.form.aporte_socio_ars).toBe(80000)
    w.unmount()
  })

  it('guardarla sin tocar nada manda el descuento y las líneas como se cobraron, no un total', async () => {
    const { updateDispensacion } = await import('../lib/api.js')
    updateDispensacion.mockClear()
    const w = await montar('admin')
    await w.vm.handleSubmit()
    const payload = updateDispensacion.mock.calls[0][1]
    expect(payload.aporte_socio_ars).toBeUndefined()
    expect(payload.descuento_dispensa_ars).toBe('91000.00')
    expect(payload.items.map(i => i.precio_manual_ars)).toEqual([10500, 12000, 10500, 10500])
    w.unmount()
  })

  it('una con descuento en pesos muestra las líneas al bruto y el descuento aparte', async () => {
    // Líneas guardadas ya descontadas: 10 × 90 = 900 cobrados, con $100 de descuento.
    const conDescuento = { ...DISPENSA, aporte_socio_ars: 900, subtotal_productos_ars: 900, descuento_dispensa_ars: 100,
      items: [{ id: 1, stock_id: 5, cantidad: 10, precio_unitario_ars: 90, stock: { id: 5, forma_producto: 'flor_seca', unidad: 'g' } }] }
    setActivePinia(createPinia())
    useAuthStore().user = { role: 'admin' }
    const Modal = (await import('../components/pacientes/ModalEditarDispensacion.vue')).default
    const w = mount(Modal, {
      props: { modelValue: true, dispensacion: conDescuento },
      global: { stubs: { Teleport: true, AppDatePicker: true, DsSpinner: true }, directives: { modal: vModal } },
    })
    await flushPromises()
    expect(w.vm.totalSugerido).toBe(1000)
    expect(w.vm.form.descuento_ars).toBe(100)
    w.unmount()
  })

  it('nadie ve un precio para tipear, tampoco el dispensador', async () => {
    const w = await montar('dispensador')
    expect(w.text()).not.toContain('Precio total')
    expect(w.find('.med__price-input').exists()).toBe(false)
    w.unmount()
  })
})

// AC (6-oct-2026, Javi): si el paciente paga MENOS, la diferencia va a la cuenta corriente,
// también al editar. Se dice en pantalla y viaja como lo que pagó; el precio no se toca.
describe('Editar dispensa — «Paga con»', () => {
  const DISPENSA = {
    id: 91, paciente_nombre: 'Martín Blanco', cantidad: 100, aporte_socio_ars: 171000, subtotal_productos_ars: 171000,
    fecha_dispensacion: '2026-10-05', medio_pago: 'transferencia', observaciones: '',
    items: [{ id: 1, stock_id: 5, cantidad: 100, precio_unitario_ars: 1710, stock: { id: 5, forma_producto: 'flor_seca', unidad: 'g' } }],
    paciente_saldo_cc: 0, paciente_limite_cc: 300000,
  }
  async function montar(dispensa = DISPENSA) {
    setActivePinia(createPinia())
    useAuthStore().user = { role: 'admin' }
    const Modal = (await import('../components/pacientes/ModalEditarDispensacion.vue')).default
    const w = mount(Modal, {
      props: { modelValue: true, dispensacion: dispensa },
      global: { stubs: { Teleport: true, AppDatePicker: true, DsSpinner: true }, directives: { modal: vModal } },
    })
    await flushPromises()
    return w
  }

  it('pagó $80.000: dice que faltan $91.000 a la cuenta corriente y manda lo que pagó, con el precio intacto', async () => {
    const { updateDispensacion } = await import('../lib/api.js')
    updateDispensacion.mockClear()
    const w = await montar()
    await w.find('#med-paga-con').setValue('80000')
    expect(w.text()).toContain('91.000')
    expect(w.text()).toContain('cuenta corriente')
    await w.vm.handleSubmit()
    const payload = updateDispensacion.mock.calls[0][1]
    expect(payload.aporte_socio_ars).toBeUndefined()         // el total lo arma el backend
    expect(payload.items[0].precio_manual_ars).toBe(1710)    // el precio, intacto
    expect(payload.descuento_dispensa_ars).toBe('0.00')
    expect(payload.cobros).toEqual([{ medio: 'transferencia', monto: 80000 }])
    w.unmount()
  })

  it('sin crédito habilitado, no deja guardar un pago parcial', async () => {
    const { updateDispensacion } = await import('../lib/api.js')
    updateDispensacion.mockClear()
    const w = await montar({ ...DISPENSA, paciente_limite_cc: 0 })
    await w.find('#med-paga-con').setValue('80000')
    await w.vm.handleSubmit()
    expect(updateDispensacion).not.toHaveBeenCalled()
    expect(w.text()).toContain('no tiene crédito habilitado')
    w.unmount()
  })

  it('pagando justo no manda líneas: el total por el medio elegido', async () => {
    const { updateDispensacion } = await import('../lib/api.js')
    updateDispensacion.mockClear()
    const w = await montar()
    await w.vm.handleSubmit()
    expect(updateDispensacion.mock.calls[0][1].cobros).toBeUndefined()
    w.unmount()
  })
})

// AC (6-oct-2026, «no podemos errar en estos detalles»): abrir para editar una dispensa que dejó
// una parte a cuenta corriente y guardar sin tocar nada NO puede convertirla en «pagó todo».
describe('Editar dispensa con una parte a cuenta corriente', () => {
  const DISPENSA = {
    id: 92, paciente_nombre: 'Martín Blanco', cantidad: 100, aporte_socio_ars: 171000, subtotal_productos_ars: 171000,
    fecha_dispensacion: '2026-10-05', medio_pago: 'mixto', observaciones: '',
    items: [{ id: 1, stock_id: 5, cantidad: 100, precio_unitario_ars: 1710, stock: { id: 5, forma_producto: 'flor_seca', unidad: 'g' } }],
    cobros: [{ medio: 'transferencia', monto_ars: 80000, pagado: true }, { medio: 'cuenta_corriente', monto_ars: 91000, pagado: false }],
    paciente_saldo_cc: -91000, paciente_limite_cc: 200000,
  }
  async function montar() {
    setActivePinia(createPinia())
    useAuthStore().user = { role: 'admin' }
    const Modal = (await import('../components/pacientes/ModalEditarDispensacion.vue')).default
    const w = mount(Modal, {
      props: { modelValue: true, dispensacion: DISPENSA },
      global: { stubs: { Teleport: true, AppDatePicker: true, DsSpinner: true }, directives: { modal: vModal } },
    })
    await flushPromises()
    return w
  }

  it('abre con lo que pagó y el medio con el que pagó, y muestra la deuda', async () => {
    const w = await montar()
    expect(w.vm.form.medio_pago).toBe('transferencia')
    expect(w.vm.montoRecibido).toBe(80000)
    expect(w.text()).toContain('91.000')
    w.unmount()
  })

  it('el crédito disponible cuenta el cupo que esta misma dispensa libera al rehacerse', async () => {
    const w = await montar()
    expect(w.vm.ccMargen).toBe(200000)          // −91.000 + 200.000 + 91.000 propios
    w.unmount()
  })

  it('guardar sin tocar nada manda lo que pagó: la deuda queda como estaba', async () => {
    const { updateDispensacion } = await import('../lib/api.js')
    updateDispensacion.mockClear()
    const w = await montar()
    await w.vm.handleSubmit()
    expect(updateDispensacion.mock.calls[0][1].cobros).toEqual([{ medio: 'transferencia', monto: 80000 }])
    w.unmount()
  })

  it('si vacían «Paga con» (pagó todo), lo manda explícito y no deja que el backend adivine', async () => {
    const { updateDispensacion } = await import('../lib/api.js')
    updateDispensacion.mockClear()
    const w = await montar()
    await w.find('#med-paga-con').setValue('')
    await w.vm.handleSubmit()
    expect(updateDispensacion.mock.calls[0][1].cobros).toEqual([{ medio: 'transferencia', monto: 171000 }])
    w.unmount()
  })
})
