import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// EL VALOR DEL ENVÍO (Germán, 23-sep-2026).
//
// AC: al crear la dispensa con delivery hay un campo «valor del envío» que se llena en ese
// momento; se suma al total, diferenciando bien el costo del envío; 0 se permite (envío
// bonificado); negativos no. Lo carga quien hace la dispensa, dispensador incluido.
const SEDE = { id: 10, nombre: 'Central' }
// 50 g a $100 = $5.000 de producto.
const STOCK = {
  id: 1, cantidad: 500, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 100,
  genetica: { id: 1, nombre: 'Lemon Cookie' }, sede: SEDE,
}
const createDispensacion = vi.fn(() => Promise.resolve({ data: { id: 99 } }))
vi.mock('../lib/api.js', () => ({
  listStocks: vi.fn(() => Promise.resolve({ data: [STOCK] })),
  createDispensacion: (...a) => createDispensacion(...a),
  getDireccionesPaciente: vi.fn(() => Promise.resolve({ data: {
    domicilio: { origen: 'domicilio', label: 'Domicilio REPROCANN', texto: 'Av. Siempreviva 742, CABA' }, guardadas: [],
  } })),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [{ id: 7, nombre: 'Repartidor' }] })),
  getMostrador: vi.fn(() => Promise.resolve({ data: { mesa: [], turno: { id: 1 } } })),
  createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
const PACIENTE = { id: 5, nombre_completo: 'Augusto Test' }

async function montar ({ envio = true } = {}) {
  setActivePinia(createPinia())
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, paciente: PACIENTE, socioId: PACIENTE.id, limiteCc: 0, saldoCc: 0 },
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: true } },
  })
  await flushPromises()
  w.vm.form.stock_id = STOCK.id
  w.vm.form.cantidad = 50
  await w.vm.$nextTick()
  w.vm.agregarItem()
  w.vm.form.con_envio = envio
  w.vm.form.delivery_id = 7
  w.vm.form.contacto_nombre = 'Augusto'
  await flushPromises()
  return w
}

const campo = w => w.find('#mnd-costo-envio')

describe('Dispensar con envío — el valor del envío', () => {
  beforeEach(() => vi.clearAllMocks())

  it('con envío aparece el campo; sin envío, no', async () => {
    expect(campo(await montar()).exists()).toBe(true)
    expect(campo(await montar({ envio: false })).exists()).toBe(false)
  })

  it('es obligatorio: sin cargar no se manda', async () => {
    const w = await montar()
    await w.vm.handleSubmit()

    expect(createDispensacion).not.toHaveBeenCalled()
    expect(w.vm.formError).toMatch(/valor del envío/)
  })

  it('se suma al total y se ve aparte del producto', async () => {
    const w = await montar()
    await campo(w).setValue(800)

    expect(w.vm.totalACobrar).toBe(5800)
    const t = w.text()
    expect(t).toContain('Productos')
    expect(t).toMatch(/Envío\s*\$\s*800/)
    expect(t).toMatch(/Total a cobrar\s*\$\s*5\.800/)

    await w.vm.handleSubmit()
    const payload = createDispensacion.mock.calls[0][1]
    expect(payload.costo_envio_ars).toBe('800.00')
    expect(payload.con_envio).toBe(true)
  })

  it('en 0 es el envío bonificado, y se manda', async () => {
    const w = await montar()
    await campo(w).setValue(0)

    expect(w.text()).toContain('Bonificado')
    expect(w.vm.totalACobrar).toBe(5000)

    await w.vm.handleSubmit()
    expect(createDispensacion.mock.calls[0][1].costo_envio_ars).toBe('0.00')
  })

  it('negativo, no', async () => {
    const w = await montar()
    await campo(w).setValue(-50)
    await w.vm.handleSubmit()

    expect(createDispensacion).not.toHaveBeenCalled()
    expect(w.vm.formError).toMatch(/negativo/)
  })

  it('un regalo no lo pide: el envío va bonificado', async () => {
    const w = await montar()
    w.vm.form.es_regalo = true
    await flushPromises()

    expect(campo(w).exists()).toBe(false)
    expect(w.text()).toContain('El envío va bonificado')
  })
})
