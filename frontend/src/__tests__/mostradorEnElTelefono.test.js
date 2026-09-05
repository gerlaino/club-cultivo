import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

vi.mock('vue-router', () => ({ useRoute: () => ({ query: {} }) }))

// EL MOSTRADOR EN EL TELÉFONO, para quien atiende.
//
// Es la mitad del día del dispensador y se usa DE PIE, con alguien enfrente. La pantalla de
// escritorio servida dentro del envoltorio le dejaba cada producto como una tarjeta de siete
// renglones —producto, variedad, lote, elaborado, precio, depósito, mostrador— así que con
// quince frascos eran cien renglones de scroll para contestar "¿tenés Northern?".
//
// Acá se verifica lo que esa pantalla tiene que cumplir, que no es cosmético:
//   · cada producto en UNA línea, con lo que hay sobre la mesa
//   · buscarlo, porque esa es la pregunta que más veces contesta por día
//   · y NUNCA revelar lo esperado antes de contar, que es de lo que depende que la merma medida
//     signifique algo.
const SEDES = [{ id: 10, nombre: 'Central', tipo: 'social' }]

const FLOR = {
  stock_id: 1, numero: 'ST-26-0031', forma: 'flor_seca', unidad: 'g', lote: 'L-26-002',
  genetica: 'Northern Lights', fecha: '2026-06-10', precio_ars: 1200, disponible: 500,
  mostrador: 297.5,
}
const PREROLL = {
  stock_id: 2, numero: 'ST-26-0061', forma: 'preroll', unidad: 'un', lote: null,
  genetica: 'Amnesia', fecha: '2026-07-02', precio_ars: 2500, disponible: 120, mostrador: 42,
}

const TURNO = {
  id: 7, estado: 'abierto', abierto_at: '2026-09-02T12:02:00Z', abierto_por: 'Ana Gómez',
  abierto_por_id: 2, caja: { id: 3, esperado_ars: 58500, otros_ingresos_efectivo_ars: 0 },
}

let respuesta = {}
const getMostrador = vi.fn(() => Promise.resolve({ data: respuesta }))
const contarMostrador = vi.fn(() => Promise.resolve({ data: {} }))

vi.mock('../composables/useStockChannel.js', () => ({ useStockChannel: () => {} }))
vi.mock('../lib/api.js', () => ({
  getMostrador:    (...a) => getMostrador(...a),
  contarMostrador: (...a) => contarMostrador(...a),
  cargarMostrador: vi.fn(), abrirMostrador: vi.fn(), cerrarMostrador: vi.fn(),
  ingresoCajaMostrador: vi.fn(), salidaCajaMostrador: vi.fn(),
  getMermaMostrador: vi.fn(() => Promise.resolve({ data: { resumen: { turnos: 0 }, por_producto: [], por_turno: [] } })),
  revisarTurnoMostrador: vi.fn(), getTurnoMostrador: vi.fn(), corregirTurnoMostrador: vi.fn(),
  listTurnosMostrador: vi.fn(() => Promise.resolve({ data: { turnos: [], gestiona: false } })),
  listRendiciones: vi.fn(() => Promise.resolve({ data: { rendiciones: [] } })),
  receptoresRendicion: vi.fn(() => Promise.resolve({ data: [] })),
  crearRendicion: vi.fn(), recibirRendicion: vi.fn(), conformarRendicion: vi.fn(),
  listSedes: vi.fn(() => Promise.resolve({ data: SEDES })),
}))

import MMostradorDispatch from '../views/mobile/MMostradorDispatch.vue'
import { useSedeStore } from '../stores/sede.js'
import { useAuthStore } from '../stores/auth.js'

// La hoja teletransporta a body y se cierra con un gesto táctil: en el test se reemplaza por un
// contenedor que muestra el slot cuando está abierta, que es lo único que se afirma acá.
const SheetStub = {
  props: ['modelValue', 'title'],
  template: '<div v-if="modelValue" class="sheet-stub"><slot /></div>',
}

async function montar (rol = 'dispensador') {
  useAuthStore().user = { id: 2, role: rol }
  const w = mount(MMostradorDispatch, {
    global: { stubs: { RouterLink: true, SheetBottom: SheetStub } },
  })
  await flushPromises()
  await flushPromises()
  return w
}

const tarjetas = (w) => w.findAll('.mmo__card')

beforeEach(() => {
  setActivePinia(createPinia())
  const sede = useSedeStore()
  sede.sedes = SEDES
  sede.loaded = true
  vi.clearAllMocks()
  respuesta = {
    mostrador: { id: 1, nombre: 'Mostrador', sede: { id: 10, nombre: 'Central' } },
    mesa: [FLOR, PREROLL], turno: TURNO, disponibles: [FLOR, PREROLL], fondo_sugerido: 50000,
  }
})

describe('Quién ve qué mostrador en el teléfono', () => {
  // Son dos trabajos distintos sobre la misma mesa: quien atiende consulta y arquea; quien
  // administra escribe cuánto tiene que haber, que es una tabla.
  it('al dispensador le sirve la pantalla de tarjetas, no la tabla', async () => {
    const w = await montar('dispensador')

    expect(w.find('.mmo').exists()).toBe(true)
    expect(w.find('.tmo__table').exists()).toBe(false)
  })

  it('a administración le sirve la de escritorio, que es donde gobierna la mesa', async () => {
    for (const rol of ['admin', 'supervisor']) {
      const w = await montar(rol)
      expect(w.find('.tmo__table').exists()).toBe(true)
      expect(w.find('.mmo').exists()).toBe(false)
    }
  })
})

describe('La mesa, para quien atiende', () => {
  it('cada producto en una línea, con lo que hay sobre la mesa', async () => {
    const w = await montar()

    expect(tarjetas(w)).toHaveLength(2)
    const flor = tarjetas(w).find(t => t.text().includes('Northern Lights'))
    expect(flor.find('.mmo__card-prod').text()).toBe('Flor seca')
    expect(flor.find('.mmo__card-cant').text()).toContain('297,5')
    expect(flor.find('.mmo__card-cant').text()).toContain('g')
  })

  // La pregunta que más veces contesta por día es "¿tenés de esto?", con el paciente enfrente.
  it('el buscador encuentra por variedad', async () => {
    const w = await montar()

    await w.find('.mmo__buscar').setValue('amnesia')

    expect(tarjetas(w)).toHaveLength(1)
    expect(tarjetas(w)[0].text()).toContain('Amnesia')
  })

  it('lo que no está sobre la mesa no aparece: él no dispensa del depósito', async () => {
    respuesta = { ...respuesta, mesa: [FLOR] }
    const w = await montar()

    expect(tarjetas(w)).toHaveLength(1)
    expect(w.text()).not.toContain('Amnesia')
  })

  // El cartel no puede proponerle algo que el backend le va a rechazar: la mesa la carga
  // administración, así que "bajá lo que falte del depósito" es justo lo único que no puede.
  it('con la mesa vacía manda a pedírselo a administración', async () => {
    respuesta = { ...respuesta, mesa: [] }
    const w = await montar()

    expect(w.find('.mmo__vacio').text()).toContain('administración')
  })
})

describe('La caja', () => {
  it('con turno abierto ofrece cerrar, y dice desde cuándo', async () => {
    const w = await montar()

    expect(w.find('.mmo__btn').text()).toBe('Cerrar caja')
    expect(w.find('.mmo__caja').text()).toContain('Caja abierta')
  })

  it('sin turno ofrece abrir', async () => {
    respuesta = { ...respuesta, turno: null }
    const w = await montar()

    expect(w.find('.mmo__btn').text()).toBe('Abrir caja')
    expect(w.find('.mmo__caja').text()).toContain('Caja cerrada')
  })

  // CUÁNTO DEBERÍA HABER EN EL CAJÓN, a la vista todo el día (sep-2026). Estuvo escondido para
  // que nadie escribiera el número que tenía delante en vez de terminar de contar; pesó más
  // poder salir a buscar la diferencia en el momento —el vuelto mal dado— en vez de descubrirla
  // al día siguiente, cuando ya no la puede explicar nadie.
  it('dice cuánto tendría que haber en el cajón', async () => {
    const w = await montar()

    expect(w.find('.mmo__caja-esperado').text()).toContain('58.500')
  })

  it('con la caja cerrada no hay cajón del que hablar', async () => {
    respuesta = { ...respuesta, turno: null }
    const w = await montar()

    expect(w.find('.mmo__caja-esperado').exists()).toBe(false)
  })

  // Los gramos tampoco se tapan: misma decisión, y por lo mismo.
  it('las cantidades de la mesa siguen a la vista mientras se cuenta', async () => {
    const w = await montar()

    await w.find('.mmo__btn').trigger('click')   // abre el conteo de cierre

    expect(tarjetas(w)[0].find('.mmo__card-cant').text()).toContain('297,5')
  })
})

describe('La hoja del producto', () => {
  it('guarda el resto de los datos, que de pie no se leen', async () => {
    const w = await montar()

    await tarjetas(w).find(t => t.text().includes('Northern')).trigger('click')

    const hoja = w.find('.sheet-stub')
    expect(hoja.text()).toContain('L-26-002')     // lote
    expect(hoja.text()).toContain('10/06/26')     // elaborado
    expect(hoja.text()).toContain('$1.200')       // precio
    expect(hoja.text()).toContain('500')          // en el depósito
  })

  // Contar un frasco suelto existe porque cerrar y reabrir con quince productos son veinte
  // minutos: el control que cuesta eso no se hace.
  it('deja contar ese producto con la caja abierta', async () => {
    const w = await montar()

    await tarjetas(w)[0].trigger('click')

    expect(w.find('.sheet-stub').text().toLowerCase()).toContain('contar')
  })

  // Con la caja cerrada el gesto es abrir, que ya cuenta todo.
  it('con la caja cerrada no ofrece contar de a uno', async () => {
    respuesta = { ...respuesta, turno: null }
    const w = await montar()

    await tarjetas(w)[0].trigger('click')

    expect(w.find('.sheet-stub').text()).toContain('caja abierta')
    expect(w.find('.sheet-stub .mmo__btn').exists()).toBe(false)
  })
})
