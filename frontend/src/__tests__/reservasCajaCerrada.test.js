import { describe, it, expect, vi, beforeEach } from 'vitest'
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
const entregarReserva = vi.fn(() => Promise.resolve({ data: {} }))
const errorToast = vi.fn()

vi.mock('../lib/api.js', () => ({
  listReservas:    (...a) => listReservas(...a),
  getMostrador:    (...a) => getMostrador(...a),
  entregarReserva: (...a) => entregarReserva(...a),
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

beforeEach(() => { errorToast.mockClear(); entregarReserva.mockClear() })

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

  it('cuando el backend rechaza, se muestra SU motivo y no un "no se pudo" pelado', async () => {
    const w = await montar(true)
    entregarReserva.mockRejectedValueOnce({
      response: { data: { error: 'La caja del mostrador está cerrada: contá y abrila antes de dispensar.' } },
    })

    await w.find('.mres__btn').trigger('click')
    await flushPromises()

    expect(errorToast).toHaveBeenCalledWith(expect.stringContaining('caja del mostrador'))
  })
})
