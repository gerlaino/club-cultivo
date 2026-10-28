import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// LA INVITACIÓN AL PORTAL EN LA PRÓXIMA DISPENSA (Germán, 27-oct-2026).
//
// AC: al dispensar, un tilde «Mandarle por mail cómo entrar a su portal». Aparece sólo si el
// backend dice que se ofrece (tiene mail y no lo activó); viene marcado salvo que ya se lo haya
// invitado este mes; destildado no se manda.
const STOCK = {
  id: 1, cantidad: 500, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 100,
  genetica: { id: 1, nombre: 'Lemon Cookie' }, sede: { id: 10, nombre: 'Central' },
}
const createDispensacion = vi.fn(() => Promise.resolve({ data: { id: 99 } }))
const getInvitacionPortal = vi.fn()
const toastSuccess = vi.fn()
vi.mock('../lib/api.js', () => ({
  listStocks: vi.fn(() => Promise.resolve({ data: [STOCK] })),
  createDispensacion: (...a) => createDispensacion(...a),
  getInvitacionPortal: (...a) => getInvitacionPortal(...a),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  getMostrador: vi.fn(() => Promise.resolve({ data: { mesa: [], turno: { id: 1 } } })),
  createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: toastSuccess, error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

async function montar (invitacion) {
  getInvitacionPortal.mockResolvedValue({ data: { data: invitacion } })
  setActivePinia(createPinia())
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, socioId: 5, limiteCc: 0, saldoCc: 0 },
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: true } },
  })
  await flushPromises()
  w.vm.form.stock_id = STOCK.id
  w.vm.form.cantidad = 10
  await w.vm.$nextTick()
  w.vm.agregarItem()
  await flushPromises()
  return w
}
const tilde = w => w.find('[data-test="invitar-portal"] input')

describe('Dispensar — la invitación al portal', () => {
  beforeEach(() => vi.clearAllMocks())

  it('si el backend no lo ofrece, no hay tilde y no se manda', async () => {
    const w = await montar({ ofrecer: false, marcada: false })
    expect(tilde(w).exists()).toBe(false)

    await w.vm.handleSubmit()
    expect(createDispensacion.mock.calls[0][1]).not.toHaveProperty('invitar_portal')
  })

  it('ofrecido y marcado: se manda con la dispensa y el aviso lo dice', async () => {
    createDispensacion.mockResolvedValueOnce({ data: { id: 99, invitacion_portal: { mail_enviado: true } } })
    const w = await montar({ ofrecer: true, marcada: true })
    expect(tilde(w).element.checked).toBe(true)

    await w.vm.handleSubmit()
    expect(getInvitacionPortal).toHaveBeenCalledWith(5)
    expect(createDispensacion.mock.calls[0][1].invitar_portal).toBe(true)
    expect(toastSuccess).toHaveBeenCalledTimes(1)
    expect(toastSuccess.mock.calls[0][0]).toContain('portal')
  })

  it('destildado no se manda', async () => {
    const w = await montar({ ofrecer: true, marcada: true })
    await tilde(w).setValue(false)

    await w.vm.handleSubmit()
    expect(createDispensacion.mock.calls[0][1]).not.toHaveProperty('invitar_portal')
  })

  it('ya invitado este mes: aparece sin marcar, y marcándolo se manda', async () => {
    const w = await montar({ ofrecer: true, marcada: false })
    expect(tilde(w).element.checked).toBe(false)
    expect(w.text()).toContain('Ya se lo invitamos este mes')

    await tilde(w).setValue(true)
    await w.vm.handleSubmit()
    expect(createDispensacion.mock.calls[0][1].invitar_portal).toBe(true)
  })
})
