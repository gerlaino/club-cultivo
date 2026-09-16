import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { vModal } from '../directives/modal.js'

// AC (Germán, 16-sep-2026): «hice una dispensa y no marqué que era por delivery; cuando la
// quiero editar no me da la opción». Editar ofrece «Mandar por delivery»: repartidor y dirección
// con la misma regla que al crear, sin tocar lo cobrado.
const updateDispensacion = vi.fn(() => Promise.resolve({ data: {} }))
const agregarEnvioDispensacion = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api.js', () => ({
  updateDispensacion: (...a) => updateDispensacion(...a),
  agregarEnvioDispensacion: (...a) => agregarEnvioDispensacion(...a),
  listEntregadores: vi.fn(() => Promise.resolve({ data: { data: [{ id: 7, nombre: 'Beto Reparto' }] } })),
  getDireccionesPaciente: vi.fn(() => Promise.resolve({ data: {
    domicilio: { texto: 'Av. Siempreviva 742, CABA' }, envio: null,
  } })),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

const DISPENSA = {
  id: 90, paciente_id: 5, paciente_nombre: 'Augusto Test', cantidad: 10, aporte_socio_ars: 1000,
  fecha_dispensacion: '2026-09-16', medio_pago: 'efectivo', observaciones: '', con_envio: false,
  items: [{ id: 1, stock_id: 5, cantidad: 10, precio_unitario_ars: 100, stock: { id: 5, forma_producto: 'flor_seca', unidad: 'g' } }],
}

async function montar (dispensacion = DISPENSA, features = { delivery: true }) {
  setActivePinia(createPinia())
  const { useClubStore } = await import('../stores/club')
  useClubStore().data = { features }
  const Modal = (await import('../components/pacientes/ModalEditarDispensacion.vue')).default
  const w = mount(Modal, {
    props: { modelValue: true, dispensacion },
    global: { stubs: { Teleport: true, AppDatePicker: true, DsSpinner: true }, directives: { modal: vModal } },
  })
  await flushPromises()
  return w
}

describe('Editar dispensación — mandar por delivery', () => {
  beforeEach(() => vi.clearAllMocks())

  it('ofrece «Mandar por delivery» a la que salió sin envío', async () => {
    const w = await montar()
    expect(w.text()).toContain('Mandar por delivery')
    expect(w.find('.med__envio').exists()).toBe(false)
  })

  it('al prenderlo pide repartidor y muestra las direcciones del paciente con el texto', async () => {
    const w = await montar()
    await w.find('.med__envio-toggle').trigger('click')
    await flushPromises()

    expect(w.text()).toContain('Beto Reparto')
    expect(w.text()).toContain('Domicilio REPROCANN')
    expect(w.text()).toContain('Av. Siempreviva 742, CABA')
  })

  it('sin repartidor no manda nada', async () => {
    const w = await montar()
    await w.find('.med__envio-toggle').trigger('click')
    await flushPromises()
    await w.vm.handleSubmit()

    expect(w.vm.formError).toContain('repartidor')
    expect(updateDispensacion).not.toHaveBeenCalled()
    expect(agregarEnvioDispensacion).not.toHaveBeenCalled()
  })

  it('guarda lo editado y DESPUÉS agrega el envío con la dirección elegida', async () => {
    const w = await montar()
    await w.find('.med__envio-toggle').trigger('click')
    await flushPromises()
    w.vm.envio.delivery_id = 7
    w.vm.envio.notas_envio = 'tocar timbre'
    await w.vm.handleSubmit()
    await flushPromises()

    expect(updateDispensacion).toHaveBeenCalled()
    expect(agregarEnvioDispensacion).toHaveBeenCalledWith(90, expect.objectContaining({
      delivery_id: 7, direccion_origen: 'domicilio', notas_envio: 'tocar timbre',
    }))
  })

  it('si lo financiero rebota, el envío no se manda', async () => {
    updateDispensacion.mockRejectedValueOnce({ response: { data: { error: 'no' } } })
    const w = await montar()
    await w.find('.med__envio-toggle').trigger('click')
    await flushPromises()
    w.vm.envio.delivery_id = 7
    await w.vm.handleSubmit()
    await flushPromises()

    expect(agregarEnvioDispensacion).not.toHaveBeenCalled()
  })

  it('la que ya va por delivery lo dice y no ofrece el toggle', async () => {
    const w = await montar({ ...DISPENSA, con_envio: true, delivery_nombre: 'Beto Reparto', direccion_envio: 'Lavalle 400, CABA' })

    expect(w.text()).toContain('Va por delivery con Beto Reparto')
    expect(w.text()).toContain('Lavalle 400, CABA')
    expect(w.find('.med__envio-toggle').exists()).toBe(false)
  })

  it('sin el add-on de Delivery no aparece nada de esto', async () => {
    const w = await montar(DISPENSA, { delivery: false })
    expect(w.text()).not.toContain('Mandar por delivery')
  })
})
