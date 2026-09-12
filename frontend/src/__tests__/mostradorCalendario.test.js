import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// LOS CIERRES, EN UN CALENDARIO (sep-2026, idea de Germán).
//
// Era una lista agrupada por día. Con una grilla del mes se ve el PATRÓN —si falta los viernes,
// si es un goteo o un día suelto— y buscar una fecha es tocarla. Fechas, no tarjetas: el estado
// es una marca debajo del número («los números así sueltos no se entiende por qué son»), y el
// detalle está AL LADO, con los cierres del día ya desplegados y sus botones.
//
// Lo que cuenta cada cierre (`hechosDelCierre`) se prueba en `corregirConteo.test.js`.

// Todas las fechas en hora LOCAL, armadas con componentes: `toISOString()` es UTC y de noche
// cambia de día, y el calendario agrupa por día local.
const local = (y, m, d, h = 12) => new Date(y, m - 1, d, h).toISOString()
const HOY = new Date()
const Y = HOY.getFullYear(), M = HOY.getMonth() + 1

const TURNO = {
  id: 7,
  abierto_at: local(Y, M, 5, 17), cerrado_at: local(Y, M, 5, 23),
  atendio: 'Ana Gómez', cerrado_por: 'Ana Gómez', productos: 4, revisado: false,
  dispensado: 120, dispensado_ars: 480000,
  motivos_revision: ['faltante', 'mesa_movida'],
  faltaron: {
    total: 1, cantidad: 23, ars: 27636.6,
    items: [{ etiqueta: 'Critical Kush L-26-017', cantidad: 23, unidad: 'g',
              ars: 27636.6, esperado: 46, contado: 23 }],
  },
  sobraron: { total: 0, cantidad: 0, ars: 0, items: [] },
  caja: { fondo_ars: 110000, esperado_ars: 150000, contado_ars: 130000, diferencia_ars: -20000 },
  bloqueo_correccion: null,
}
const LIMPIO = {
  ...TURNO, id: 8, abierto_at: local(Y, M, 3, 10), cerrado_at: local(Y, M, 3, 20),
  motivos_revision: [], faltaron: { total: 0, ars: 0, items: [] }, sobraron: { total: 0, items: [] },
  caja: { ...TURNO.caja, contado_ars: 150000, diferencia_ars: 0 },
  bloqueo_correccion: { motivo: 'caja_posterior', texto: 'Después de este cierre se volvió a abrir la caja.' },
}

let respuestaMes = { mes: `${Y}-${String(M).padStart(2, '0')}`, turnos: [TURNO, LIMPIO], gestiona: true, sin_revisar: 1 }
let respuestaPend = { turnos: [TURNO], gestiona: true, pagina: 1, paginas: 1, total: 1, sin_revisar: 1 }
const revisarTurnoMostrador = vi.fn(() => Promise.resolve({ data: {} }))
const listTurnos = vi.fn()
vi.mock('../lib/api.js', () => ({
  listTurnosMostrador: (sede, params) => {
    listTurnos(sede, params)
    return Promise.resolve({ data: params?.sin_revisar ? respuestaPend : respuestaMes })
  },
  descargarTurnosMostrador: vi.fn(),
  corregirTurnoMostrador: vi.fn(),
  getTurnoMostrador: vi.fn(() => Promise.resolve({ data: { items: [] } })),
  revisarTurnoMostrador: (...a) => revisarTurnoMostrador(...a),
  reabrirRevisionTurnoMostrador: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

import MostradorTurnos from '../components/mostrador/MostradorTurnos.vue'

async function montar ({ turnos = [TURNO, LIMPIO], gestiona = true, pendientes = [TURNO] } = {}) {
  respuestaMes  = { ...respuestaMes, turnos, gestiona }
  respuestaPend = { ...respuestaPend, turnos: pendientes, sin_revisar: pendientes.length }
  const w = mount(MostradorTurnos, { props: { sedeId: 10 } })
  await flushPromises()
  return w
}

// `disabled=""` es un string vacío: falsy, pero presente.
const diasActivos = (w) => w.findAll('.trn__dia').filter(d => !d.classes('trn__dia--vacia') && d.attributes('disabled') === undefined)
const celda = (w, n) => w.findAll('.trn__dia').find(d => d.text().trim() === String(n))

beforeEach(() => { setActivePinia(createPinia()); revisarTurnoMostrador.mockClear(); listTurnos.mockClear() })

describe('La grilla del mes', () => {
  it('pide el mes en curso entero, no una página', async () => {
    await montar()
    expect(listTurnos).toHaveBeenCalledWith(10, { mes: `${Y}-${String(M).padStart(2, '0')}` })
  })

  it('un día con caja se puede tocar; uno sin caja, no', async () => {
    const w = await montar()
    expect(diasActivos(w).map(d => d.text().trim())).toEqual(['3', '5'])
    expect(celda(w, 1).attributes('disabled')).toBeDefined()
  })

  // EL ESTADO ES UNA MARCA, NO UN TEXTO. El ámbar salta solo; no hay nada que leer hasta tocar.
  it('el día que faltó algo va en ámbar y el que no, en gris', async () => {
    const w = await montar()
    expect(celda(w, 5).classes()).toContain('is-warn')
    expect(celda(w, 3).classes()).not.toContain('is-warn')
    expect(celda(w, 5).text().trim()).toBe('5')   // sin números sueltos adentro
  })

  it('la plata que falta también pinta el día', async () => {
    const w = await montar({ turnos: [{ ...LIMPIO, motivos_revision: ['caja'], caja: { ...LIMPIO.caja, diferencia_ars: -8500 } }] })
    expect(celda(w, 3).classes()).toContain('is-warn')
  })

  it('el día más reciente arranca elegido: es el que se viene a mirar', async () => {
    const w = await montar()
    expect(celda(w, 5).classes()).toContain('is-sel')
    expect(w.find('.trn__panel-titulo').text()).toMatch(/5 de/)
  })

  it('no se puede ir al mes que viene', async () => {
    const w = await montar()
    expect(w.find('[aria-label="Mes siguiente"]').attributes('disabled')).toBeDefined()
  })

  it('ir al mes anterior pide ese mes', async () => {
    const w = await montar()
    await w.find('[aria-label="Mes anterior"]').trigger('click')
    await flushPromises()
    const ant = new Date(Y, M - 2, 1)
    expect(listTurnos).toHaveBeenCalledWith(10, { mes: `${ant.getFullYear()}-${String(ant.getMonth() + 1).padStart(2, '0')}` })
  })
})

describe('El panel del día', () => {
  it('tocar un día abre sus cierres, con la cuenta a la vista', async () => {
    const w = await montar()
    await celda(w, 3).trigger('click')

    const panel = w.find('.trn__panel')
    expect(panel.text()).toMatch(/3 de/)
    expect(panel.text()).toContain('estaba todo')
    expect(panel.findAll('.trn__cierre')).toHaveLength(1)
  })

  it('dice qué pasó, en oraciones, con el producto por su nombre', async () => {
    const w = await montar()
    const t = w.find('.trn__panel').text()
    expect(t).toContain('Faltan 23 g')
    expect(t).toContain('Critical Kush')
    expect(t).toContain('tenía que haber 46 g')
    expect(t).toContain('20.000 menos')
  })

  it('el veredicto de cada cierre se lee sin abrir nada', async () => {
    const w = await montar()
    expect(w.find('.trn__panel .trn__pill').text()).toBe('Falta producto')
  })

  // La plata manda sobre el producto: es lo que un admin quiere que le griten primero.
  it('si faltó plata, el veredicto es ése aunque también falte producto', async () => {
    const w = await montar({ turnos: [{ ...TURNO, motivos_revision: ['caja', 'faltante'] }] })
    expect(w.find('.trn__panel .trn__pill').text()).toBe('Falta plata')
  })

  // CUÁNDO FUE, SIN QUE PAREZCA IMPOSIBLE: una caja que cruzó la medianoche nombra el día en que abrió.
  it('cuando la caja cruzó la medianoche, nombra el día en que abrió', async () => {
    const w = await montar({ turnos: [{ ...TURNO, abierto_at: local(Y, M, 4, 22), cerrado_at: local(Y, M, 5, 1) }] })
    expect(w.find('.trn__hora').text()).toMatch(/^(lunes|martes|miércoles|jueves|viernes|sábado|domingo) /)
  })

  it('y cuando abrió uno y cerró otro, nombra a los dos', async () => {
    const w = await montar({ turnos: [{ ...TURNO, atendio: 'Ana Gómez', cerrado_por: 'Beto Ruiz' }] })
    expect(w.find('.trn__cierre-meta').text()).toContain('abrió Ana Gómez, cerró Beto Ruiz')
  })
})

// SÓLO EL ÚLTIMO SE CORRIGE (regla de Germán, que la app ya aplicaba): si después se abrió otra
// caja, se volvió a contar y la diferencia se arregla ahí. Se DICE, no se esconde el botón.
describe('Corregir y marcar', () => {
  it('el último cierre ofrece «Corregir»; uno con caja posterior, no, y dice por qué', async () => {
    const w = await montar()
    expect(w.find('.trn__panel').text()).toContain('Corregir el conteo')

    await celda(w, 3).trigger('click')
    const panel = w.find('.trn__panel')
    expect(panel.text()).not.toContain('Corregir el conteo')
    expect(panel.find('.trn__bloqueo').text()).toContain('se volvió a abrir la caja')
  })

  it('«Corregir» abre la ficha', async () => {
    const w = await montar()
    await w.find('.trn__btn--primary').trigger('click')
    expect(w.findComponent({ name: 'CorregirConteo' }).exists()).toBe(true)
  })

  // Archivar no mueve nada: «Ya lo miré» queda siempre, y se refleja sin esperar la recarga.
  it('«Ya lo miré» marca el cierre y lo saca de la franja de pendientes', async () => {
    const w = await montar()
    expect(w.find('.trn__pend').text()).toContain('1 cierre para mirar')

    await w.find('.trn__panel .trn__btn--ghost').trigger('click')
    await flushPromises()

    expect(revisarTurnoMostrador).toHaveBeenCalledWith(10, 7)
    expect(w.find('.trn__panel .trn__pill').text()).toBe('Visto')
    expect(w.find('.trn__pend').exists()).toBe(false)
  })

  it('quien atiende ve sus cierres pero no los botones ni la franja', async () => {
    const w = await montar({ gestiona: false, pendientes: [] })
    expect(w.find('.trn__pend').exists()).toBe(false)
    expect(w.find('.trn__panel').text()).not.toContain('Corregir')
    expect(w.find('.trn__panel').text()).not.toContain('Ya lo miré')
  })
})

// LA LISTA DE TRABAJO VA ARRIBA DE LA GRILLA, no enterrada en ella: es una lista que se vacía.
describe('«Para mirar», arriba del calendario', () => {
  it('lista los pendientes con su día y su motivo, y tocarlos elige el día', async () => {
    const w = await montar()
    const btn = w.find('.trn__pend-btn')
    expect(btn.text()).toMatch(/5\/\d+ · falta producto/)

    await celda(w, 3).trigger('click')
    await btn.trigger('click')
    expect(celda(w, 5).classes()).toContain('is-sel')
  })

  it('si el pendiente es de otro mes, cambia de mes y lo elige al llegar', async () => {
    const ant = new Date(Y, M - 2, 9)
    const viejo = { ...TURNO, id: 3, abierto_at: local(ant.getFullYear(), ant.getMonth() + 1, 9, 10), cerrado_at: local(ant.getFullYear(), ant.getMonth() + 1, 9, 20) }
    const w = await montar({ pendientes: [viejo] })
    respuestaMes = { ...respuestaMes, turnos: [viejo] }

    await w.find('.trn__pend-btn').trigger('click')
    await flushPromises()

    expect(listTurnos).toHaveBeenCalledWith(10, { mes: `${ant.getFullYear()}-${String(ant.getMonth() + 1).padStart(2, '0')}` })
    expect(celda(w, 9).classes()).toContain('is-sel')
  })

  it('cuando no hay nada para mirar, no ocupa lugar', async () => {
    const w = await montar({ pendientes: [] })
    expect(w.find('.trn__pend').exists()).toBe(false)
  })
})
