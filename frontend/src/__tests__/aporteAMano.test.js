import { describe, it, expect, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { vModal } from '../directives/modal.js'

// AC (5-oct-2026): cuando administración pisa el aporte a mano, el «Total» que se ve es lo que se
// cobra, y la diferencia con los productos aparece como «Ajuste manual». Antes el recuadro decía
// Total $60.000 con un aporte de $22.000 abajo, y se cobraban los $22.000.

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

describe('Nueva dispensa — aporte a mano', () => {
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

  it('sin tocar el aporte, el total es el de los productos y no hay ajuste', async () => {
    const w = await montar()
    expect(filaTotal(w)).toContain('60.000')
    expect(w.text()).not.toContain('Ajuste manual')
  })

  it('con el aporte pisado, el total es el aporte y la diferencia se ve', async () => {
    const w = await montar()
    w.vm.form.aporte_socio_ars = 22000
    await w.vm.$nextTick()
    expect(filaTotal(w)).toContain('22.000')
    expect(w.text()).toContain('Ajuste manual')
    expect(w.text()).toContain('38.000')
    expect(w.vm.totalACobrar).toBe(22000)                    // lo que se ve es lo que se cobra
  })
})

describe('Editar dispensa — aporte a mano', () => {
  // La dispensa de la imagen: líneas que suman $171.000, total cobrado $80.000.
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

  it('administración ve la diferencia entre los productos y el total como ajuste', async () => {
    const w = await montar('admin')
    expect(w.text()).toContain('171.000')
    expect(w.text()).toContain('Ajuste manual')
    expect(w.text()).toContain('91.000')
    w.unmount()
  })

  it('el dispensador no ve un aporte editable: el backend no se lo acepta', async () => {
    const w = await montar('dispensador')
    expect(w.text()).not.toContain('Aporte del paciente')
    expect(w.text()).not.toContain('Ajuste manual')
    w.unmount()
  })
})
