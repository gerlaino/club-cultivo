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
    //
    // Y DICE "LIBRES", que es lo que evita la otra lectura: sin esa palabra, "95" con "15
    // reservados" al lado invita a restar de nuevo — o a cargar de más creyendo que el 95 era el
    // total. Germán leyó exactamente eso en el teléfono.
    const disp = w.find('.mnd__td-disp-n').text()
    expect(disp).toContain('95g')
    expect(disp).toContain('libres')
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

// ── RESERVADO Y LIBRE SON COLUMNAS, NO UN CARTEL DEBAJO DEL INPUT ──────────────────
//
// Iban como una línea suelta pegada al input de Mostrador, y ahí decían algo imposible:
// «mostrador 0 · 15 reservados». Esos 15 g no están sobre la mesa —están en el depósito, que ya
// los descontó—: `reservado` es un dato del PRODUCTO, no de la mesa. Colgado de la columna
// equivocada, un número correcto se lee como un error. Lo vio Germán probando en producción.
describe('La mesa dice qué tiene dueño y qué se puede vender', () => {
  const FILAS = [
    // El caso de la captura: nada arriba, 15 reservados que viven en el depósito.
    { stock_id: 1, forma: 'flor_seca', unidad: 'g', genetica: 'Northern Lights', numero: 'ST-26-0001',
      mostrador: 0, reservado: 15, disponible: 470.1, libre: 470.1 },
    // Y el caso con mercadería arriba.
    { stock_id: 2, forma: 'hash', unidad: 'g', genetica: 'Zamaleña', numero: 'ST-02',
      mostrador: 40, reservado: 0, disponible: 300, libre: 340 },
  ]

  async function tabla (props = {}) {
    const { default: Tabla } = await import('../components/mostrador/TablaMostrador.vue')
    return mount(Tabla, {
      // `muestraCosto` = administración: es quien gobierna la mesa y quien ve estas columnas.
      props: { stocks: FILAS, modelValue: {}, editable: false, muestraCosto: true, ...props },
      global: { stubs: { RouterLink: true } },
    })
  }

  // POR FILA, NO POR POSICIÓN: la tabla ordena sola —lo que está sobre la mesa primero— así que
  // atarse al índice hace que el test falle por el orden y no por lo que se está probando.
  const fila = (w, numero) =>
    w.findAll('tbody tr').find(r => r.text().includes(numero))
  const celda = (w, numero, col) => fila(w, numero).find(`[data-col="${col}"]`).text()

  it('lo reservado tiene columna propia y no cuelga del input de la mesa', async () => {
    const w = await tabla()
    expect(w.find('.tmo__reservado').exists()).toBe(false)   // el cartel viejo, que mentía

    expect(celda(w, 'ST-26-0001', 'Reservado')).toContain('15')
    expect(celda(w, 'ST-02',       'Reservado')).toContain('0')
  })

  it('con la mesa en cero, lo reservado sigue siendo del producto: no dice que hay 15 arriba', async () => {
    const w = await tabla()
    expect(celda(w, 'ST-26-0001', 'Mostrador')).toContain('0')
    // El dato existe, pero en su propia columna — no pegado al 0 de la mesa.
    expect(celda(w, 'ST-26-0001', 'Reservado')).toContain('15')
  })

  // Se probó una columna «Libre» (= Depósito − Reservado) y se sacó al verla renderizada: con la
  // mesa vacía —que es casi toda la tabla— da exactamente lo mismo que Depósito, o sea una
  // columna repetida en 20 de 21 filas. El número vive donde se decide con él: el carrito.
  it('no hay columna «Libre»: repetía a Depósito en casi todas las filas', async () => {
    const w = await tabla()
    expect(w.find('[data-col="Libre"]').exists()).toBe(false)
  })

  it('también están cargando la mesa: bajar por debajo de lo reservado se ve antes', async () => {
    const w = await tabla({ editable: true })
    expect(celda(w, 'ST-26-0001', 'Reservado')).toContain('15')
  })

  it('a quien atiende no se le muestran: no gobierna la mesa ni ve el depósito', async () => {
    const w = await tabla({ muestraCosto: false })
    expect(w.find('[data-col="Reservado"]').exists()).toBe(false)
  })
})

// ── EL TECHO DEL CARRITO ES EL DEL BACKEND ─────────────────────────────────────────
//
// El bug que reportó Germán probando en el teléfono: sobre un frasco con gramos ya reservados,
// el carrito ofrecía el frasco ENTERO y la dispensa rebotaba al confirmar. `cantidad` es la fila
// del stock; el techo es `disponible_para_entregar`, el mismo número que valida
// `Dispensacion#stock_disponible`.
describe('Dispensar — no se ofrece lo que ya tiene dueño', () => {
  const CON_RESERVA = [
    { id: 1, cantidad: 1679.7, disponible_para_entregar: 1664.7, reservado: 15, unidad: 'g',
      forma_producto: 'flor_seca', precio_sugerido_ars: 100, genetica: { nombre: 'Amnesia Haze' },
      fecha_elaboracion: '2026-05-12', sede: SEDE },
  ]

  async function conCarrito() {
    listStocks.mockResolvedValue({ data: CON_RESERVA })
    setActivePinia(createPinia())
    const { useAuthStore } = await import('../stores/auth.js')
    useAuthStore().user = { id: 1, role: 'admin' }
    const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
    const w = mount(Modal, {
      props: { modelValue: true, socioId: PACIENTE.id },
      global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: true } },
    })
    await flushPromises(); await flushPromises()
    return w
  }

  it('muestra el techo real, no el frasco entero', async () => {
    const w = await conCarrito()
    const disp = w.find('.mnd__td-disp-n').text()
    expect(disp).toContain('1664.7')
    expect(disp).not.toContain('1679.7')
  })

  it('no deja agregar al carrito más de lo que el backend acepta', async () => {
    const w = await conCarrito()
    w.vm.form.stock_id = 1

    w.vm.form.cantidad = 1670          // entra en el frasco, pero pisa lo reservado
    await flushPromises()
    expect(w.vm.excederiaStock).toBe(true)

    w.vm.form.cantidad = 1664          // debajo del techo
    await flushPromises()
    expect(w.vm.excederiaStock).toBe(false)
  })
})

// ── LA COLUMNA MOSTRADOR TAMBIÉN ORDENA ────────────────────────────────────────────
//
// Era la única de las ocho que no lo hacía, y es por la que más se quiere ordenar: "¿de qué tengo
// más arriba?" y "¿qué se está por acabar?" son la misma pregunta desde los dos extremos. Un
// encabezado que no responde entre siete que sí se lee como que esa columna está rota.
describe('Ordenar por lo que hay sobre la mesa', () => {
  const FILAS = [
    { stock_id: 1, forma: 'flor_seca', unidad: 'g', genetica: 'A', numero: 'ST-A', mostrador: 40,  disponible: 100, reservado: 0, libre: 140 },
    { stock_id: 2, forma: 'flor_seca', unidad: 'g', genetica: 'B', numero: 'ST-B', mostrador: 200, disponible: 100, reservado: 0, libre: 300 },
    { stock_id: 3, forma: 'flor_seca', unidad: 'g', genetica: 'C', numero: 'ST-C', mostrador: 0,   disponible: 100, reservado: 0, libre: 100 },
  ]

  async function tabla () {
    const { default: Tabla } = await import('../components/mostrador/TablaMostrador.vue')
    return mount(Tabla, {
      props: { stocks: FILAS, modelValue: {}, editable: false, muestraCosto: true },
      global: { stubs: { RouterLink: true } },
    })
  }

  const orden = (w) => w.findAll('tbody tr').map(r => r.find('[data-col="Mostrador"]').text().trim())
  const encabezado = (w) => w.findAll('.tmo__th').find(t => t.text().includes('Mostrador'))

  it('el encabezado se puede tocar y ordena de menor a mayor', async () => {
    const w = await tabla()
    await encabezado(w).find('button').trigger('click')
    expect(orden(w).map(t => parseFloat(t))).toEqual([0, 40, 200])
  })

  it('el segundo click lo da vuelta', async () => {
    const w = await tabla()
    await encabezado(w).find('button').trigger('click')
    await encabezado(w).find('button').trigger('click')
    expect(orden(w).map(t => parseFloat(t))).toEqual([200, 40, 0])
  })

  it('ordenando por esa columna, los ceros NO se van al final', async () => {
    // El agrupado por defecto —lo que está sobre la mesa arriba— tiene que apagarse acá: si no,
    // "de menor a mayor" daría 40, 200, 0, que es cualquier cosa menos ascendente.
    const w = await tabla()
    await encabezado(w).find('button').trigger('click')
    expect(parseFloat(orden(w)[0])).toBe(0)
  })
})
