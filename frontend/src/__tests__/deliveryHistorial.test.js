import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

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

// SU historial son DOS preguntas: qué entregué, y cómo cerró cada caja que rendí. La segunda no
// estaba en ningún lado para él — el historial de rendiciones existía, pero escrito para
// administración (una tabla con columna "Repartidor", que para él es siempre él).
const RENDICIONES = [
  { id: 4, estado: 'recibida', receptor: 'Ada Admin', declarado_ars: 200000,
    recibido_ars: 180000, diferencia_ars: -20000, motivo: 'trajo 180, el resto mañana',
    conforme: false, recibida_at: '2026-08-06T20:00:00-03:00' },
  { id: 5, estado: 'recibida', receptor: 'Dana Dispensa', declarado_ars: 50000,
    recibido_ars: 50000, diferencia_ars: 0, conforme: null,
    recibida_at: '2026-08-05T20:00:00-03:00' },
  // Una pendiente NO es historia: todavía está pasando, y se ve en Caja.
  { id: 6, estado: 'pendiente', receptor: 'Ada Admin', declarado_ars: 9000 },
]
const listRendiciones = vi.fn(() =>
  Promise.resolve({ data: { rendiciones: RENDICIONES, mi_saldo_ars: 20000, cajas_abiertas: [] } }))

vi.mock('../lib/api.js', () => ({
  getMiHistorialDelivery: (...a) => getMiHistorialDelivery(...a),
  listRendiciones:        (...a) => listRendiciones(...a),
}))

describe('Historial del delivery', () => {
  let wrapper

  beforeEach(async () => {
    vi.clearAllMocks()
    const { default: Vista } = await import('../views/mobile/MDeliveryHistorialView.vue')
    wrapper = mount(Vista)
    // Con `flushPromises` y no con vueltas de `setTimeout(0)`: eso último pasa o falla según
    // cuán ocupada esté la máquina, que es la peor clase de rojo.
    await flushPromises()
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

  describe('la solapa de cajas rendidas', () => {
    beforeEach(async () => {
      await wrapper.findAll('.mdh__tab')[1].trigger('click')
      await flushPromises()
    })

    it('muestra sólo las cerradas: una pendiente todavía está pasando', () => {
      expect(wrapper.findAll('.mdh__card').length).toBe(2)
    })

    it('dice cuánto cobró, cuánto le recibieron y quién', () => {
      const primera = wrapper.findAll('.mdh__card')[0]

      expect(primera.text()).toContain('$200.000 cobrados')
      expect(primera.text()).toContain('Ada Admin')
      expect(primera.text()).toContain('$180.000')
    })

    // No es una pérdida ni una falta: esa plata existe y la tiene él.
    it('la diferencia se dice como lo que es, con el motivo', () => {
      const primera = wrapper.findAll('.mdh__card')[0]

      expect(primera.text()).toContain('$20.000 a tu nombre')
      expect(primera.text()).toContain('el resto mañana')
      expect(primera.text()).toContain('Falta que digas si estás de acuerdo')
    })

    it('la que cuadró lo dice, sin ruido', () => {
      const segunda = wrapper.findAll('.mdh__card')[1]

      expect(segunda.find('.mdh__estado').text()).toBe('Cuadró')
      expect(segunda.text()).not.toContain('a tu nombre')
    })
  })
})
