import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'

// El endpoint del delivery devuelve el paciente ANIDADO (`paciente.nombre`). La vista leía
// `paciente_nombre`, que es la forma de otros endpoints (turnos) y acá no existe: cada tarjeta
// del historial mostraba un guion donde va el nombre.
const PAQUETES = [
  {
    id: 1, estado_envio: 'entregado', direccion_envio: 'Rivadavia 5066',
    entregado_at: '2026-08-07T21:38:00-03:00',
    paciente: { id: 9, nombre: 'Ana Gómez' }, contacto_nombre: 'Ana Gómez',
  },
  {
    id: 2, estado_envio: 'fallido', direccion_envio: 'Av. 5627',
    fallido_at: '2026-08-07T20:41:00-03:00', motivo_fallo: 'Dirección inexistente',
    // Sin paciente anidado: se cae al contacto, que es a quien se le iba a entregar.
    paciente: null, contacto_nombre: 'Beto Pérez',
  },
]

const getMiHistorialDelivery = vi.fn(() =>
  Promise.resolve({ data: { dispensaciones: PAQUETES, resumen: { entregados: 1, fallidos: 1 } } }))

vi.mock('../lib/api.js', () => ({ getMiHistorialDelivery: (...a) => getMiHistorialDelivery(...a) }))

describe('Historial del delivery', () => {
  let wrapper

  beforeEach(async () => {
    vi.clearAllMocks()
    const { default: Vista } = await import('../views/mobile/MDeliveryHistorialView.vue')
    wrapper = mount(Vista)
    for (let i = 0; i < 4; i++) await new Promise((r) => setTimeout(r, 0))
  })

  it('muestra el nombre del paciente además de la dirección', () => {
    const primera = wrapper.findAll('.mdh__card')[0]

    expect(primera.find('.mdh__paciente').text()).toBe('Ana Gómez')
    expect(primera.find('.mdh__dir').text()).toBe('Rivadavia 5066')
  })

  it('cuando no hay paciente cargado usa el contacto de la entrega, no un guion', () => {
    const segunda = wrapper.findAll('.mdh__card')[1]

    expect(segunda.find('.mdh__paciente').text()).toBe('Beto Pérez')
  })

  it('no queda ninguna tarjeta con guion en el nombre', () => {
    const nombres = wrapper.findAll('.mdh__paciente').map((n) => n.text())

    expect(nombres).not.toContain('—')
  })

  it('el fallido muestra su motivo y la fecha en que falló', () => {
    const segunda = wrapper.findAll('.mdh__card')[1]

    expect(segunda.find('.mdh__motivo').text()).toBe('Dirección inexistente')
    expect(segunda.find('.mdh__fecha').text()).toContain('07/08')
  })

  it('cambiar el rango de días vuelve a pedir el historial', async () => {
    expect(getMiHistorialDelivery).toHaveBeenCalledWith(30)

    await wrapper.find('.mdh__rango').setValue('7')

    expect(getMiHistorialDelivery).toHaveBeenLastCalledWith(7)
  })
})
