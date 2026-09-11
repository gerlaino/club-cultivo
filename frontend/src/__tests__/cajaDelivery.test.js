import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { vModal } from '../directives/modal.js'

// LA CAJA DEL REPARTIDOR, EN SU PROPIA SOLAPA.
//
// El monto de una rendición lo pone el sistema —pedirle que se acuerde de lo que cobró en doce
// puertas es pedirle un error— pero NUNCA se lo mostrábamos: rendía a ciegas, sin poder contar
// los billetes contra nada. Y la tarjeta de rendición vivía arriba de todo en el INICIO, que es
// la pantalla que abre para saber a dónde va.

let caja = {
  efectivo_ars: 200000,
  cobros: [
    { id: 1, monto_ars: 120000, paciente: 'Rocío Medina',    hora: '2026-09-10T18:20:00Z' },
    { id: 2, monto_ars: 80000,  paciente: 'Santiago Torres', hora: '2026-09-10T19:05:00Z' },
  ],
  transferencias_ars: 12500,
  paquetes_sin_entregar: 3,
  saldo_a_cuenta_ars: 0,
}
const getMiCajaDelivery = vi.fn(() => Promise.resolve({ data: caja }))

vi.mock('../lib/api.js', () => ({
  getMiCajaDelivery:   (...a) => getMiCajaDelivery(...a),
  listRendiciones:     vi.fn(() => Promise.resolve({ data: { rendiciones: [], mi_saldo_ars: 0, cajas_abiertas: [] } })),
  receptoresRendicion: vi.fn(() => Promise.resolve({ data: [{ id: 5, nombre: 'Ada', rol: 'admin' }] })),
  crearRendicion:      vi.fn(() => Promise.resolve({ data: {} })),
  recibirRendicion:    vi.fn(() => Promise.resolve({ data: {} })),
  conformarRendicion:  vi.fn(() => Promise.resolve({ data: {} })),
  getMisPaquetes:      vi.fn(() => Promise.resolve({ data: { dispensaciones: [] } })),
  iniciarViaje:        vi.fn(() => Promise.resolve({ data: {} })),
  ordenarRuta:         vi.fn(() => Promise.resolve({ data: {} })),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
vi.mock('../composables/useEntregasOffline.js', () => ({
  useEntregasOffline: () => ({ pendientes: { value: [] }, entregarConReintento: vi.fn(), fallaConReintento: vi.fn() }),
}))

import { useAuthStore } from '../stores/auth.js'

async function montarCaja () {
  setActivePinia(createPinia())
  useAuthStore().user = { id: 9, role: 'delivery' }
  const Vista = (await import('../views/delivery/CajaDeliveryView.vue')).default
  const w = mount(Vista, { global: { stubs: { Teleport: true }, directives: { modal: vModal } } })
  await flushPromises()
  await flushPromises()
  return w
}

beforeEach(() => { vi.clearAllMocks() })

describe('La caja del repartidor', () => {
  it('le dice cuánto lleva encima, que es lo que venía a saber', async () => {
    const w = await montarCaja()
    expect(w.find('.cjd__total-n').text()).toBe('$200.000')
    expect(w.text()).toContain('2 entregas cobradas')
    w.unmount()
  })

  it('trae el detalle entrega por entrega, para poder contarlo', async () => {
    const w = await montarCaja()
    const filas = w.findAll('.cjd__fila').map(f => f.text())
    expect(filas.length).toBe(2)
    expect(filas[0]).toContain('Rocío Medina')
    expect(filas[0]).toContain('$120.000')
    w.unmount()
  })

  // Esa plata ya entró a la cuenta de la organización: sumarla sería pedirle billetes que
  // nunca tuvo.
  it('lo de transferencia se dice aparte y no suma al total', async () => {
    const w = await montarCaja()
    expect(w.find('.cjd__total-n').text()).toBe('$200.000')
    expect(w.find('.cjd__transf').text()).toMatch(/no lo rendís/i)
    w.unmount()
  })

  it('avisa que vuelve con paquetes sin entregar', async () => {
    const w = await montarCaja()
    expect(w.find('.cjd__paquetes').text()).toContain('3')
    w.unmount()
  })

  it('desde ahí rinde: la acción no se quedó en el inicio', async () => {
    const w = await montarCaja()
    expect(w.text()).toContain('Rendir la caja')
    w.unmount()
  })
})

describe('El inicio del repartidor', () => {
  async function montarInicio () {
    setActivePinia(createPinia())
    useAuthStore().user = { id: 9, role: 'delivery' }
    const Vista = (await import('../views/delivery/DeliveryDashboard.vue')).default
    const w = mount(Vista, { global: { stubs: { Teleport: true }, directives: { modal: vModal } } })
    await flushPromises()
    return w
  }

  // Esta pantalla se abre cuarenta veces por día para saber a dónde ir. Arrancaba con un recibo
  // ("Rendiste $200.000, esperando que la reciban"), que no es una tarea.
  it('no tiene nada de plata: eso vive en la solapa Caja', async () => {
    const w = await montarInicio()
    expect(w.find('.rnd').exists()).toBe(false)
    expect(w.text()).not.toMatch(/rendir la caja/i)
    w.unmount()
  })

  // Al lado de "Pendientes 0" y "En camino 0" —que son de hoy— había un "Entregados 26" que
  // contaba toda su vida. Parado en la vereda no dice nada; en Historial hay período.
  it('no muestra el contador histórico de entregados', async () => {
    const w = await montarInicio()
    expect(w.findAll('.dlv__stat-l').map(s => s.text())).not.toContain('Entregados')
    w.unmount()
  })

  // ES LO ÚNICO QUE LE RECUERDA QUE TIENE QUE RENDIR. La tarjeta de la caja salió del inicio a
  // propósito —esa pantalla es a dónde va ahora— pero si nada se lo dice, se va a su casa con la
  // recaudación. Un punto, no un número: acá no se cuenta plata, se avisa que hay.
  it('el punto de la solapa se enciende con lo que lleva encima', async () => {
    setActivePinia(createPinia())
    const { useCajaDeliveryStore } = await import('../stores/cajaDelivery.js')
    const store = useCajaDeliveryStore()

    expect(store.llevaEfectivo).toBe(false)   // sin dato todavía no se pinta nada
    await store.cargar()
    expect(store.llevaEfectivo).toBe(true)
  })

  it('y se apaga cuando ya no lleva nada', async () => {
    setActivePinia(createPinia())
    const { useCajaDeliveryStore } = await import('../stores/cajaDelivery.js')
    const store = useCajaDeliveryStore()

    getMiCajaDelivery.mockResolvedValueOnce({ data: { ...caja, efectivo_ars: 0, cobros: [] } })
    await store.cargar()
    expect(store.llevaEfectivo).toBe(false)
  })

  // "Vacío" y "no se pudo cargar" no son lo mismo: decirle tranquilamente que no lleva nada a
  // alguien que tiene plata encima es lo peor que le podemos contestar.
  it('si la consulta falla no dice que no lleva nada: dice que no se pudo', async () => {
    setActivePinia(createPinia())
    const { useCajaDeliveryStore } = await import('../stores/cajaDelivery.js')
    const store = useCajaDeliveryStore()

    getMiCajaDelivery.mockRejectedValueOnce(new Error('sin red'))
    await store.cargar()
    expect(store.error).toBe(true)
    expect(store.caja).toBeNull()
  })
})
