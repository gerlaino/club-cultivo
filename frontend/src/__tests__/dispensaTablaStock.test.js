import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC: elegir el producto a dispensar se hace comparando entre frascos, no leyendo uno por uno.
//
// La lista anterior ponía forma de producto, genética, fecha y precio en spans en línea dentro de
// un botón: el dato estaba, pero no se podía escanear una columna hacia abajo para comparar. Ahora
// es una tabla con columnas alineadas y ordenables, y la DISPONIBILIDAD va última contra el borde
// derecho, que es el número que se mira de un golpe de vista antes de elegir.
//
// El teléfono no tiene ancho para cinco columnas, así que convive con las tarjetas de siempre. Son
// dos markups de la misma lista, y el test verifica justamente que no se despeguen.
const UNA_SEDE = { id: 10, nombre: 'Central' }
const STOCKS = [
  { id: 1, cantidad: 340, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 1800,
    genetica: { id: 1, nombre: 'Lemon Cookie' }, fecha_elaboracion: '2026-05-12',
    descripcion: 'frasco chico', sede: UNA_SEDE },
  { id: 2, cantidad: 120, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 2100,
    genetica: { id: 2, nombre: 'Blue Sherbet' }, fecha_elaboracion: '2026-06-03', sede: UNA_SEDE },
  { id: 3, cantidad: 45, unidad: 'g', forma_producto: 'hash', precio_sugerido_ars: 4500,
    genetica: { id: 3, nombre: 'Zamaleña' }, fecha_elaboracion: '2026-04-28', sede: UNA_SEDE },
]

const listStocks = vi.fn(() => Promise.resolve({ data: STOCKS }))
vi.mock('../lib/api.js', () => ({
  listStocks: (...a) => listStocks(...a),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  createDispensacion: vi.fn(), createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

const PACIENTE = { id: 5, nombre_completo: 'Ana Gómez', cuenta_corriente: {} }

async function montar(stocks = STOCKS, rol = 'admin') {
  listStocks.mockResolvedValue({ data: stocks })
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 1, role: rol }
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, paciente: PACIENTE, socioId: PACIENTE.id },
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true } },
  })
  for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))
  return w
}

const genetica = (w) => w.findAll('.mnd__td-gen-nombre').map((c) => c.text())

describe('Dispensar — la tabla de productos', () => {
  beforeEach(() => vi.clearAllMocks())

  it('renderiza una fila por stock, con sus columnas', async () => {
    const w = await montar()

    expect(w.find('.mnd__tabla').exists()).toBe(true)
    expect(w.findAll('.mnd__tr')).toHaveLength(3)

    const fila = w.findAll('.mnd__tr')[0]
    expect(fila.find('.mnd__td-prod').text()).toContain('Flor seca')
    expect(fila.find('.mnd__td-gen-nombre').text()).toBe('Blue Sherbet')
    expect(fila.find('.mnd__td-disp').text()).toContain('120g')
  })

  // Lo que pidió Germán explícitamente: verla en una punta.
  it('la disponibilidad es la última columna, contra el borde derecho', async () => {
    const w = await montar()

    const encabezados = w.findAll('.mnd__tabla thead th').map((t) => t.text().trim())
    expect(encabezados[encabezados.length - 1]).toContain('Disp.')

    const celdas = w.findAll('.mnd__tr')[0].findAll('td')
    expect(celdas[celdas.length - 1].classes()).toContain('mnd__td-disp')
  })

  it('arranca ordenada por genética, que es lo que se busca', async () => {
    const w = await montar()

    expect(genetica(w)).toEqual(['Blue Sherbet', 'Lemon Cookie', 'Zamaleña'])
  })

  it('tocar una columna ordena por ella, y volver a tocarla la da vuelta', async () => {
    const w = await montar()
    const th = (label) => w.findAll('.mnd__th-btn').find((b) => b.text().includes(label))

    await th('Disp.').trigger('click')
    expect(genetica(w)).toEqual(['Zamaleña', 'Blue Sherbet', 'Lemon Cookie']) // 45 · 120 · 340

    await th('Disp.').trigger('click')
    expect(genetica(w)).toEqual(['Lemon Cookie', 'Blue Sherbet', 'Zamaleña']) // 340 · 120 · 45

    await th('Fecha').trigger('click')
    expect(genetica(w)).toEqual(['Zamaleña', 'Lemon Cookie', 'Blue Sherbet']) // abr · may · jun
  })

  it('el buscador filtra por genética, producto u observación', async () => {
    const w = await montar()

    await w.find('.mnd__buscador-input').setValue('sherbet')
    expect(genetica(w)).toEqual(['Blue Sherbet'])

    await w.find('.mnd__buscador-input').setValue('hash')
    expect(genetica(w)).toEqual(['Zamaleña'])

    // La observación es lo que distingue dos frascos que en la tabla se ven iguales.
    await w.find('.mnd__buscador-input').setValue('frasco chico')
    expect(genetica(w)).toEqual(['Lemon Cookie'])
  })

  // Si el filtro esconde lo que estaba elegido, la selección tiene que soltarse: si no, se
  // dispensa algo que ya no está en pantalla.
  it('filtrar suelta la selección que dejó de verse', async () => {
    const w = await montar()

    await w.findAll('.mnd__tr')[0].trigger('click')
    expect(w.vm.form.stock_id).toBe(2)

    await w.find('.mnd__buscador-input').setValue('hash')
    await new Promise((r) => setTimeout(r, 0))
    expect(w.vm.form.stock_id).toBe(null)
  })

  // Un radio de verdad, no un div con @click: la selección con teclado y el lector de pantalla
  // salen gratis, como salían con el botón que había antes.
  it('cada fila se elige con un radio real', async () => {
    const w = await montar()

    const radios = w.findAll('.mnd__radio')
    expect(radios).toHaveLength(3)
    expect(radios[0].attributes('type')).toBe('radio')

    await radios[2].setValue(true)
    expect(w.vm.form.stock_id).toBe(3)
  })

  // Las tarjetas del teléfono leen la MISMA lista: si se despegan, el celular muestra otra cosa.
  it('la vista de tarjetas muestra los mismos stocks que la tabla', async () => {
    const w = await montar()

    expect(w.findAll('.mnd__stock-row')).toHaveLength(w.findAll('.mnd__tr').length)

    await w.find('.mnd__buscador-input').setValue('sherbet')
    expect(w.findAll('.mnd__stock-row')).toHaveLength(1)
    expect(w.findAll('.mnd__tr')).toHaveLength(1)
  })
})


// "SIN STOCK DISPONIBLE" ES FALSO PARA EL QUE ATIENDE.
//
// El dispensador saca de la mesa, no del depósito. Con el mostrador cerrado el depósito está
// lleno y la lista viene vacía: decirle que no hay stock lo manda a buscar un problema que no
// existe, y a los cinco minutos llama por teléfono. Es el peor error posible — parece culpa suya.
describe('Dispensar — la lista vacía dice por qué', () => {
  beforeEach(() => vi.clearAllMocks())

  it('al dispensador le dice que la mesa está vacía, y dónde se arregla', async () => {
    const w = await montar([], 'dispensador')
    const aviso = w.find('.mnd__warn-box').text()

    expect(aviso).toContain('sobre la mesa')
    expect(aviso).toContain('Mostrador')
    expect(w.text()).not.toContain('Sin stock disponible')
  })

  // Y le propone SÓLO lo que puede hacer. La mesa la carga administración: mandarlo a bajar del
  // depósito es invitarlo a una acción que el backend le rechaza, que es el mismo error de
  // "la pantalla te deja y el backend te frena" con otro disfraz.
  it('no lo manda a bajar producto del depósito, que es lo único que no puede hacer', async () => {
    const w = await montar([], 'dispensador')
    const aviso = w.find('.mnd__warn-box').text()

    expect(aviso).toContain('administración')
    expect(aviso).not.toMatch(/bajá lo que falte/i)
  })

  // Administración dispensa del depósito: para ella la lista vacía sí significa que no hay stock.
  it('y a administración, que no hay stock', async () => {
    const w = await montar([], 'admin')

    expect(w.find('.mnd__warn-box').text()).toContain('Sin stock disponible')
  })

  it('lo mismo para el supervisor, que es administración', async () => {
    const w = await montar([], 'supervisor')

    expect(w.find('.mnd__warn-box').text()).toContain('Sin stock disponible')
  })
})

// AC (Germán): administración dispensa del depósito entero, más allá de lo que haya en el
// mostrador — pero si lo que elige está sobre la mesa, la dispensa va a descontar de ahí. Un
// badge en la fila se lo dice ANTES de elegir, para que no se entere a la noche cuando el que
// atiende cierra con un faltante que no esperaba.
describe('Dispensar — el badge de Mostrador', () => {
  beforeEach(() => vi.clearAllMocks())

  const CON_MOSTRADOR = [
    { id: 1, cantidad: 340, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 1800,
      genetica: { id: 1, nombre: 'Lemon Cookie' }, sede: UNA_SEDE, en_mostrador: true },
    { id: 2, cantidad: 120, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 2100,
      genetica: { id: 2, nombre: 'Blue Sherbet' }, sede: UNA_SEDE, en_mostrador: false },
  ]

  it('a administración le marca cuál está sobre la mesa', async () => {
    const w = await montar(CON_MOSTRADOR, 'admin')
    const filas = w.findAll('.mnd__tr')

    // Ordenada por genética: Blue Sherbet (sin badge) primero, Lemon Cookie (con badge) después.
    expect(filas[0].find('.mnd__td-prod').text()).not.toContain('Mostrador')
    expect(filas[1].find('.mnd__td-prod').text()).toContain('Mostrador')
  })

  // Al dispensador ya se le filtró la lista a lo que está sobre la mesa (lo resuelve el
  // backend): cada fila trae `en_mostrador: true`, pero repetirlo en un badge por fila no le
  // dice nada que no supiera ya por estar viendo sólo eso.
  it('al dispensador no le muestra el badge, aunque el backend lo mande', async () => {
    const w = await montar(CON_MOSTRADOR, 'dispensador')

    expect(w.text()).not.toContain('Mostrador')
  })
})
