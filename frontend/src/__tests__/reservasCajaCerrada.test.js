import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// ENTREGAR UNA RESERVA CREA UNA DISPENSA, y sin caja abierta el backend la rechaza: lo cobrado en
// efectivo no tendría dónde caer. La lista se llena igual —las reservas están ahí—, así que sin
// aviso el botón se aprieta y rebota, con el paciente enfrente.
//
// Y cuando rebota, el mensaje tiene que decir QUÉ pasó: el endpoint contesta `{ errors: [...] }`
// y la pantalla leía sólo `error`, así que mostraba "No se pudo entregar" pelado — la persona no
// sabe si es la caja, el stock o la fecha.

const RESERVAS = [
  { id: 7, cantidad: 10, aporte_restante_ars: 17084, fecha_entrega_estimada: '2026-08-01',
    paciente: { id: 3, nombre: 'Diego Benítez' }, stock: { unidad: 'g', forma_producto: 'flor_seca' } },
]

let turno = { id: 1 }
const listReservas   = vi.fn(() => Promise.resolve({ data: { reservas: RESERVAS } }))
const getMostrador   = vi.fn(() => Promise.resolve({ data: { turno } }))
const errorToast = vi.fn()

vi.mock('../lib/api.js', () => ({
  listReservas:    (...a) => listReservas(...a),
  getMostrador:    (...a) => getMostrador(...a),
}))
// El modal se stubbea a propósito: montarlo entero probaría el modal, no esta pantalla. Lo que
// se afirma acá es que se abre y con qué datos.
vi.mock('../components/pacientes/ModalNuevaDispensacion.vue', () => ({
  default: {
    name: 'ModalNuevaDispensacion',
    props: ['modelValue', 'socioId', 'pacienteNombre', 'saldoCc', 'limiteCc', 'reserva'],
    emits: ['update:modelValue', 'saved'],
    template: '<div class="modal-stub" />',
  },
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: (...a) => errorToast(...a), warning: vi.fn(), info: vi.fn() }),
}))

import MReservasView from '../views/mobile/MReservasView.vue'

async function montar (conCaja = true, rol = 'dispensador') {
  turno = conCaja ? { id: 1 } : null
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 1, role: rol, dispensario_sede: { id: 10 } }
  const w = mount(MReservasView, { global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } } })
  await flushPromises()
  return w
}

beforeEach(() => { errorToast.mockClear() })

describe('Entregar una reserva desde el teléfono', () => {
  it('con la caja abierta, se puede', async () => {
    const w = await montar(true)

    expect(w.find('.mres__aviso').exists()).toBe(false)
    expect(w.find('.mres__btn').attributes('disabled')).toBeUndefined()
  })

  it('con la caja cerrada avisa ANTES, y no deja apretar', async () => {
    const w = await montar(false)

    const aviso = w.find('.mres__aviso')
    expect(aviso.exists()).toBe(true)
    expect(aviso.text()).toContain('caja del mostrador está cerrada')
    expect(aviso.text()).toContain('Mostrador')          // dónde se arregla
    expect(w.find('.mres__btn').attributes('disabled')).toBeDefined()
  })

  // El backend sigue siendo el que decide: trabar las entregas por un request que no salió es
  // peor que dejar que rechace.
  it('si no se pudo preguntar por la caja, no traba nada', async () => {
    getMostrador.mockRejectedValueOnce(new Error('sin red'))
    const w = await montar(true)

    expect(w.find('.mres__aviso').exists()).toBe(false)
    expect(w.find('.mres__btn').attributes('disabled')).toBeUndefined()
  })

  // Al admin no le aplica el mostrador: dispensa del depósito entero.
  it('a administración no se le pregunta por la caja', async () => {
    getMostrador.mockClear()
    await montar(false, 'admin')

    expect(getMostrador).not.toHaveBeenCalled()
  })

  // ENTREGAR NO ENTREGA: ABRE EL MODAL, con todo precargado.
  //
  // Con un toque suelto la entrega salía a ciegas: sin ver la seña ya paga ni el resto a cobrar,
  // sin poder elegir el medio de pago —salía con el de la reserva, y si era cuenta corriente y el
  // paciente no la tiene habilitada, rebotaba— y sin poder ajustar la cantidad real.
  it('abre el modal de dispensa con la reserva cargada, no entrega de una', async () => {
    const w = await montar(true)

    await w.find('.mres__btn').trigger('click')
    await flushPromises()

    const modal = w.findComponent({ name: 'ModalNuevaDispensacion' })
    expect(modal.exists()).toBe(true)
    expect(modal.props('reserva').id).toBe(7)
    expect(modal.props('pacienteNombre')).toBe('Diego Benítez')
  })

  it('y al cerrarlo sin entregar, suelta la reserva', async () => {
    const w = await montar(true)
    await w.find('.mres__btn').trigger('click')
    await flushPromises()

    await w.findComponent({ name: 'ModalNuevaDispensacion' }).vm.$emit('update:modelValue', false)
    await flushPromises()

    expect(w.findComponent({ name: 'ModalNuevaDispensacion' }).exists()).toBe(false)
  })
})

// QUÉ DICE CADA TARJETA. Germán, mirándola en el teléfono: «me gustaría un poquito más de info en
// ese detalle, como por ejemplo la genética, y la que está señada debería decir cuánto resta
// pagar, no sólo señada, porque puede estar señada y con un resto todavía por cobrar».
//
// Decir «Señada ✓» sobre una reserva con la mitad sin cobrar es peor que no decir nada: el que
// atiende la entrega sin cobrar el resto, y el que paga la diferencia es el club.
describe('Lo que cuenta la tarjeta de una reserva', () => {
  const conStock = (extra, stock = {}) => [{
    id: 7, cantidad: 5, fecha_entrega_estimada: '2026-08-11',
    paciente: { id: 3, nombre: 'Diego Cabrera' },
    stock: { unidad: 'g', forma_producto: 'flor_seca', genetica: 'Critical Kush',
             lote: 'L-26-017', ...stock },
    ...extra,
  }]

  const conReservas = async (rs) => {
    listReservas.mockResolvedValue({ data: { reservas: rs } })
    return montar(true)
  }
  afterEach(() => { listReservas.mockResolvedValue({ data: { reservas: RESERVAS } }) })

  it('dice la variedad, que es con lo que se va a buscar el frasco', async () => {
    const w = await conReservas(conStock({ sena_ars: 0, aporte_restante_ars: 12000 }))

    expect(w.find('.mres__prod').text()).toBe('Critical Kush')
    expect(w.find('.mres__meta').text()).toContain('5g · Flor seca')
    expect(w.find('.mres__meta').text()).toContain('L-26-017')
  })

  it('señada Y con resto dice las dos cosas', async () => {
    const w = await conReservas(conStock({ sena_ars: 5000, aporte_restante_ars: 12000 }))

    const txt = w.find('.mres__cobro').text()
    expect(txt).toContain('5.000')    // lo que ya puso
    expect(txt).toContain('12.000')   // lo que hay que cobrarle ahora
    expect(w.find('.mres__cobro').classes()).toContain('mres__cobro--resta')
  })

  it('sin seña, sólo lo que resta', async () => {
    const w = await conReservas(conStock({ sena_ars: 0, aporte_restante_ars: 17084 }))
    expect(w.find('.mres__cobro').text()).toMatch(/^Resta/)
  })

  it('paga del todo, lo dice y muestra con cuánto', async () => {
    const w = await conReservas(conStock({ sena_ars: 17084, aporte_restante_ars: 0 }))

    expect(w.find('.mres__cobro').text()).toContain('Paga')
    expect(w.find('.mres__cobro').text()).toContain('17.084')
    expect(w.find('.mres__cobro').classes()).toContain('mres__cobro--ok')
  })

  // Sin seña y sin resto no es que esté paga: es que no se estimó el aporte al reservarla.
  // Decirle «Paga ✓» ahí es hacerle regalar la mercadería.
  it('sin seña y sin total estimado, no dice que esté paga', async () => {
    const w = await conReservas(conStock({ sena_ars: 0, aporte_restante_ars: 0 }))

    expect(w.find('.mres__cobro').text()).toBe('Se cobra al entregar')
    expect(w.find('.mres__cobro').text()).not.toContain('Paga')
  })

  it('y si no se sabe la variedad, no deja el renglón vacío', async () => {
    const w = await conReservas(conStock({ sena_ars: 0, aporte_restante_ars: 100 }, { genetica: null }))
    expect(w.find('.mres__prod').exists()).toBe(false)
  })
})
