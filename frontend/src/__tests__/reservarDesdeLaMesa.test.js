import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC: RESERVAR ES ELEGIR DE LA MESA.
//
// La reserva la hace administración y la mercadería se enfrasca recién al entregar: entre una
// cosa y la otra el producto sigue sobre la mesa del mostrador. Eligiéndolo del depósito quedaba
// una reserva que después había que bajar a mano, y hasta entonces la entregaba admin o
// supervisor — nunca el dispensador, que es el que está ahí.
//
// Tres cosas que tienen que pasar: la lista sale de la MESA; el número que se ve es lo LIBRE
// (mesa menos lo ya reservado por otro paciente) con el motivo al lado; y con la mesa vacía el
// cartel manda a bajar producto al mostrador, que es el gesto que sí puede hacer quien reserva.

const SEDE = { id: 10, nombre: 'Central' }

// El depósito: lo que se ve al DISPENSAR. Reservando no tiene que aparecer ninguno.
const DEPOSITO = [
  { id: 1, cantidad: 1000, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 1800,
    genetica: { nombre: 'Lemon Cookie' }, fecha_elaboracion: '2026-05-12', sede: SEDE },
  { id: 9, cantidad: 500, unidad: 'g', forma_producto: 'hash', precio_sugerido_ars: 4000,
    genetica: { nombre: 'Solo en el depósito' }, fecha_elaboracion: '2026-05-01', sede: SEDE },
]

// La mesa habla en su propio idioma: `stock_id`, `forma`, `genetica` como texto.
const MESA = [
  { stock_id: 1, forma: 'flor_seca', unidad: 'g', genetica: 'Lemon Cookie',
    fecha: '2026-05-12', precio_ars: 1800, mostrador: 110, reservado: 15 },
]

const listStocks   = vi.fn(() => Promise.resolve({ data: DEPOSITO }))
const getMostrador = vi.fn(() => Promise.resolve({ data: { mesa: MESA, turno: { id: 1 } } }))

vi.mock('../lib/api.js', () => ({
  listStocks:      (...a) => listStocks(...a),
  getMostrador:    (...a) => getMostrador(...a),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  createDispensacion: vi.fn(), createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

const PACIENTE = { id: 5, nombre_completo: 'Ana Gómez', cuenta_corriente: {} }

async function montar({ mesa = MESA } = {}) {
  listStocks.mockResolvedValue({ data: DEPOSITO })
  getMostrador.mockResolvedValue({ data: { mesa, turno: { id: 1 } } })
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 1, role: 'admin' }
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, socioId: PACIENTE.id, modoInicial: 'reserva' },
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: true } },
  })
  await flushPromises(); await flushPromises()
  return w
}

const geneticas = (w) => w.findAll('.mnd__td-gen-nombre').map((c) => c.text())

describe('Reservar — la lista es la mesa del mostrador', () => {
  beforeEach(() => { listStocks.mockClear(); getMostrador.mockClear() })

  it('pregunta por la mesa de la sede y lista lo que hay arriba, no el depósito', async () => {
    const w = await montar()

    expect(getMostrador).toHaveBeenCalledWith(SEDE.id)
    const nombres = geneticas(w)
    expect(nombres).toContain('Lemon Cookie')
    // El del depósito no está sobre la mesa: no se puede reservar hasta que alguien lo baje.
    expect(nombres).not.toContain('Solo en el depósito')
  })

  it('muestra lo LIBRE, no lo que hay arriba, y dice cuánto está reservado', async () => {
    const w = await montar()

    // 110 sobre la mesa, 15 de un paciente: quedan 95. Pedirle la resta al usuario es pedirle
    // la cuenta que hace la máquina.
    expect(w.find('.mnd__td-disp-n').text()).toBe('95g')
    expect(w.find('.mnd__td-reservado').text()).toContain('15')
    expect(w.find('.mnd__td-reservado').text()).toContain('reservados')
  })

  it('sin nada sobre la mesa, manda a bajar producto al mostrador', async () => {
    const w = await montar({ mesa: [] })

    const aviso = w.find('.mnd__warn-box')
    expect(aviso.exists()).toBe(true)
    expect(aviso.text()).toContain('No hay nada sobre la mesa')
    expect(aviso.text()).toContain('bajá')
    // Y el camino, no sólo el diagnóstico.
    expect(w.find('.mnd__warn-link').exists()).toBe(true)
  })
})

describe('Dispensar — sigue saliendo del depósito', () => {
  beforeEach(() => { listStocks.mockClear(); getMostrador.mockClear() })

  it('sin modo reserva, la lista es la de siempre y no se pide la mesa para armarla', async () => {
    listStocks.mockResolvedValue({ data: DEPOSITO })
    setActivePinia(createPinia())
    const { useAuthStore } = await import('../stores/auth.js')
    useAuthStore().user = { id: 1, role: 'admin' }
    const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
    const w = mount(Modal, {
      props: { modelValue: true, socioId: PACIENTE.id },
      global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: true } },
    })
    await flushPromises(); await flushPromises()

    expect(geneticas(w)).toContain('Solo en el depósito')
    w.unmount()
  })
})

// ── Y EN LA MESA SE VE CUÁNTO YA TIENE DUEÑO ───────────────────────────────────────
//
// Pedido de Germán: que aparezca en pantalla lo reservado de cada producto del mostrador, y que
// en cero diga "0 reservados" — un número que aparece de la nada el día que hay una reserva no
// se aprende a mirar.
describe('La mesa dice cuánto ya tiene dueño', () => {
  const FILAS = [
    { stock_id: 1, forma: 'flor_seca', unidad: 'g', genetica: 'Lemon Cookie', numero: 'ST-01',
      mostrador: 110, reservado: 15, disponible: 890 },
    { stock_id: 2, forma: 'hash', unidad: 'g', genetica: 'Zamaleña', numero: 'ST-02',
      mostrador: 40, reservado: 0, disponible: 300 },
  ]

  async function tabla(props = {}) {
    const { default: Tabla } = await import('../components/mostrador/TablaMostrador.vue')
    return mount(Tabla, {
      props: { stocks: FILAS, modelValue: {}, editable: false, ...props },
      global: { stubs: { RouterLink: true } },
    })
  }

  it('muestra los gramos reservados de cada producto', async () => {
    const w = await tabla()
    const textos = w.findAll('.tmo__reservado').map(n => n.text())
    expect(textos[0]).toContain('15')
    expect(textos[0]).toContain('reservados')
  })

  it('y en cero lo dice igual, apagado — no aparece de la nada el día que hay una reserva', async () => {
    const w = await tabla()
    const filas = w.findAll('.tmo__reservado')
    expect(filas).toHaveLength(2)
    expect(filas[1].text()).toContain('0')
    expect(filas[1].classes()).toContain('is-cero')
    expect(filas[0].classes()).not.toContain('is-cero')
  })

  it('también cuando administración está cargando la mesa: bajar por debajo de lo reservado se ve antes', async () => {
    const w = await tabla({ editable: true, muestraCosto: true })
    expect(w.findAll('.tmo__reservado')[0].text()).toContain('15')
  })
})
