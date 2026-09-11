import { describe, it, expect, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { vModal } from '../directives/modal.js'

// LA CC SALE DE LA DISPENSA, NO DE QUIÉN MONTÓ EL MODAL.
//
// El historial no le pasaba `saldo-cc`/`limite-cc` (la ficha del paciente sí), así que al paciente
// con crédito recién habilitado el desplegable le decía "Cuenta corriente (sin límite
// configurado)" y no lo dejaba elegirla. El mismo modal, desde una puerta sí y desde la otra no.

vi.mock('../lib/api.js', () => ({ updateDispensacion: vi.fn(() => Promise.resolve({ data: {} })) }))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

const DISPENSA = {
  id: 90, paciente_nombre: 'Natanael Casuso', cantidad: 10, aporte_socio_ars: 105000,
  fecha_dispensacion: '2026-09-08', medio_pago: 'transferencia', observaciones: '',
  items: [{ id: 1, stock_id: 5, cantidad: 10, precio_unitario_ars: 10500,
            stock: { id: 5, forma_producto: 'flor_seca', unidad: 'g' },
            genetica_nombre: 'Fruti Punchi' }],
  paciente_saldo_cc: 0, paciente_limite_cc: 80000,
}

async function montar (props = {}) {
  setActivePinia(createPinia())
  const Modal = (await import('../components/pacientes/ModalEditarDispensacion.vue')).default
  const w = mount(Modal, {
    props: { modelValue: true, dispensacion: DISPENSA, ...props },
    global: {
      stubs: { Teleport: true, AppDatePicker: true, DsSpinner: true },
      directives: { modal: vModal },
    },
  })
  await flushPromises()
  return w
}

const opcionCc = w => w.findAll('option').find(o => o.attributes('value') === 'cuenta_corriente')

describe('Editar dispensación — cuenta corriente', () => {
  it('la habilita con la CC que trae la dispensa, sin que se la pasen por props', async () => {
    const w = await montar()
    expect(opcionCc(w).attributes('disabled')).toBeUndefined()
    expect(opcionCc(w).text()).toBe('Cuenta corriente')
    w.unmount()
  })

  it('muestra el crédito disponible', async () => {
    const w = await montar()
    expect(w.text()).toContain('Crédito disponible')
    w.unmount()
  })

  it('sin crédito configurado sigue apagada, y dice por qué', async () => {
    const w = await montar({ dispensacion: { ...DISPENSA, paciente_saldo_cc: null, paciente_limite_cc: null } })
    expect(opcionCc(w).attributes('disabled')).toBeDefined()
    expect(opcionCc(w).text()).toContain('sin límite configurado')
    w.unmount()
  })

  it('si la pantalla igual las pasa, mandan las props', async () => {
    const w = await montar({ saldoCc: 0, limiteCc: 0 })
    expect(opcionCc(w).attributes('disabled')).toBeDefined()
    w.unmount()
  })
})
