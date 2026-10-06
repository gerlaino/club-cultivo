import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { vModal } from '../directives/modal.js'

// AC (Germán, 6-oct-2026): al tocar «Registrar dispensación», un modal de confirmación con los
// datos de la dispensa, y un botón para imprimir la etiqueta de la dispensa.

const STOCK = {
  id: 1, cantidad: 500, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 1710,
  genetica: { id: 1, nombre: 'Blue Sherbet' }, sede: { id: 10, nombre: 'Central' },
}
const CREADA = { id: 838, token: 'tok-838', fecha_dispensacion: '2026-10-06', items: [] }
vi.mock('../lib/api.js', () => ({
  listStocks: vi.fn(() => Promise.resolve({ data: [STOCK] })),
  createDispensacion: vi.fn(() => Promise.resolve({ data: CREADA })),
  updateDispensacion: vi.fn(), listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  getMostrador: vi.fn(() => Promise.resolve({ data: { mesa: [], turno: { id: 1 } } })),
  createReserva: vi.fn(), entregarReserva: vi.fn(), agregarEnvioDispensacion: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
const imprimirEtiqueta = vi.fn()
vi.mock('../composables/useEtiquetaDispensa.js', () => ({ useEtiquetaDispensa: () => ({ imprimirEtiqueta }) }))

const { useAuthStore } = await import('../stores/auth')
const { createDispensacion } = await import('../lib/api.js')

async function montar() {
  setActivePinia(createPinia())
  useAuthStore().user = { role: 'admin' }
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, pacienteNombre: 'Martín Blanco', socioId: 5, limiteCc: 300000, saldoCc: 0 },
    // El resumen de verdad: el setup común lo stubea para el resto de los tests.
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: true, ResumenDispensaModal: false },
              directives: { modal: vModal } },
    attachTo: document.body,
  })
  for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))
  w.vm.form.stock_id = STOCK.id
  w.vm.form.cantidad = 100                                  // 100 g × $1.710 = $171.000
  await w.vm.$nextTick()
  w.vm.agregarItem()
  await w.vm.$nextTick()
  return w
}

describe('Confirmar la dispensa antes de registrarla', () => {
  beforeEach(() => { createDispensacion.mockClear(); imprimirEtiqueta.mockClear() })

  it('muestra lo que se lleva, el total y cómo paga, y no crea nada hasta confirmar', async () => {
    const w = await montar()
    w.vm.form.medio_pago = 'transferencia'
    w.vm.montoRecibido = 80000
    await w.vm.$nextTick()

    const enviando = w.vm.handleSubmit()
    await flushPromises()
    const resumen = w.find('.rdm')
    expect(resumen.exists()).toBe(true)
    const t = resumen.text()
    expect(t).toContain('Martín Blanco')
    expect(t).toContain('100g')
    expect(t).toContain('Blue Sherbet')
    expect(t).toContain('171.000')
    expect(t).toContain('80.000')                         // lo que paga
    expect(t).toContain('91.000')                         // lo que va a la cuenta corriente
    expect(createDispensacion).not.toHaveBeenCalled()

    await w.findAll('.rdm__btn').find(b => b.text() === 'Volver').trigger('click')
    await enviando
    expect(createDispensacion).not.toHaveBeenCalled()
    expect(w.vm.saving).toBe(false)
    w.unmount()
  })

  it('«Confirmar e imprimir etiqueta» crea la dispensa e imprime la etiqueta de la creada', async () => {
    const w = await montar()
    const enviando = w.vm.handleSubmit()
    await flushPromises()
    await w.findAll('.rdm__btn').find(b => b.text().includes('imprimir etiqueta')).trigger('click')
    await enviando
    await flushPromises()

    expect(createDispensacion).toHaveBeenCalledTimes(1)
    expect(imprimirEtiqueta).toHaveBeenCalledWith(CREADA)
    w.unmount()
  })

  it('«Confirmar» crea la dispensa sin imprimir', async () => {
    const w = await montar()
    const enviando = w.vm.handleSubmit()
    await flushPromises()
    await w.findAll('.rdm__btn').find(b => b.text() === 'Confirmar').trigger('click')
    await enviando
    expect(createDispensacion).toHaveBeenCalledTimes(1)
    expect(imprimirEtiqueta).not.toHaveBeenCalled()
    w.unmount()
  })
})
