import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// LA SOLAPA DE MERMA, ORDENADA POR PREGUNTA.
//
// Era cuatro tablas apiladas —sede, producto, turno— con las MISMAS columnas y tres KPIs arriba:
// había que elegir cuál mirar antes de saber qué se estaba buscando. Y el número principal
// ("2,4% de lo entregado") no se comparaba con nada, aunque la app ya sabía si eso era mucho o
// poco: el aviso automático compara contra las ocho semanas anteriores y esta pantalla no lo usaba.

let respuesta = {}
const getMermaMostrador     = vi.fn(() => Promise.resolve({ data: respuesta }))
const revisarTurnoMostrador = vi.fn(() => Promise.resolve({ data: {} }))

vi.mock('../lib/api.js', () => ({
  getMermaMostrador:     (...a) => getMermaMostrador(...a),
  revisarTurnoMostrador: (...a) => revisarTurnoMostrador(...a),
  getTurnoMostrador:     vi.fn(() => Promise.resolve({ data: { conteo_apertura: [] } })),
  corregirTurnoMostrador: vi.fn(),
}))

import MostradorMerma from '../components/mostrador/MostradorMerma.vue'

const TURNO = {
  id: 7, cerrado_at: '2026-09-03T22:00:00Z', cerrado_por: 'Ana Gómez', atendio: 'Ana Gómez',
  dispensado: 1000, faltante: 50, faltante_ars: 5000, merma_pct: 5, motivos: ['merma'],
  correcciones: 0, revisado: false, motivos_revision: ['faltante'],
}

const BASE = {
  resumen: { turnos: 9, dispensado: 9000, faltante: 90, faltante_ars: 9000, merma_pct: 1 },
  por_producto: [
    { producto: 'Northern Lights (flor seca)', unidad: 'g', dispensado: 1000, faltante: 50,
      faltante_ars: 5000, merma_pct: 5, turnos: 3 },
  ],
  por_turno: [TURNO],
  por_sede: null,
  por_persona: [
    { usuario_id: 3, persona: 'Ana Gómez', rol: 'dispensador', turnos: 6, dispensado: 6000,
      faltante: 300, faltante_ars: 30000, merma_pct: 5, contra_promedio: 4, cerro_otro: 0,
      suficientes: true },
    { usuario_id: 4, persona: 'Beto Ruiz', rol: 'dispensador', turnos: 1, dispensado: 200,
      faltante: 20, faltante_ars: 2000, merma_pct: 10, contra_promedio: 9, cerro_otro: 1,
      suficientes: false },
  ],
  sin_revisar: 1,
  serie: [
    { semana: '2026-08-24', turnos: 4, dispensado: 4000, faltante: 20, faltante_ars: 2000, merma_pct: 0.5 },
    { semana: '2026-08-31', turnos: 5, dispensado: 5000, faltante: 70, faltante_ars: 7000, merma_pct: 1.4 },
  ],
  veredicto: {
    estado: 'subio', pct: 5.1, pct_previo: 1.2, semanas_previas: 8, dispensado: 1000,
    faltante_ars: 5000, turnos: 2, turnos_previos: 20, factor: 2,
    motor: { producto: 'Northern Lights (flor seca)', pct: 5, faltante: 50, unidad: 'g', faltante_ars: 5000 },
  },
  rango: { desde: '2026-09-01', hasta: '2026-09-06' },
}

async function montar (extra = {}, props = {}) {
  respuesta = { ...BASE, ...extra }
  const w = mount(MostradorMerma, { props: { sedeId: 10, ...props } })
  await flushPromises()
  return w
}

beforeEach(() => { getMermaMostrador.mockClear(); revisarTurnoMostrador.mockClear() })

describe('① Cómo viene', () => {
  // Un porcentaje solo no dice nada: 3% puede ser normal fraccionando flor y un escándalo en
  // aceite. Lo que importa es que CAMBIÓ respecto del patrón de esta organización.
  it('lo dice en castellano, con los dos números al lado', async () => {
    const w = await montar()

    const v = w.find('.mrm__ver-frase').text()
    expect(v).toContain('5.1%')
    expect(v).toContain('1.2%')
    expect(v).toContain('8 semanas')
  })

  // Sin esto, "subió" manda a mirar tres tablas para encontrar el renglón que ya sabemos cuál es.
  it('y dice qué producto la está moviendo', async () => {
    const w = await montar()

    expect(w.find('.mrm__ver-motor').text()).toContain('Northern Lights')
  })

  it('cuando está como siempre no inventa una alarma', async () => {
    const w = await montar({
      veredicto: { ...BASE.veredicto, estado: 'normal', motor: null, pct: 1.1, pct_previo: 1.2 },
    })

    expect(w.find('.mrm__veredicto').classes()).toContain('mrm__veredicto--ok')
    expect(w.find('.mrm__ver-motor').exists()).toBe(false)
  })

  // Quedarse en blanco se lee como que está todo bien.
  it('y cuando no hay con qué comparar, lo dice', async () => {
    const w = await montar({ veredicto: { ...BASE.veredicto, estado: 'sin_historia', motor: null } })

    expect(w.find('.mrm__ver-frase').text()).toContain('no hay con qué comparar')
  })

  it('dibuja la tendencia semana a semana', async () => {
    const w = await montar()

    expect(w.findAll('.mrm__barra')).toHaveLength(2)
  })
})

describe('② Para mirar', () => {
  it('lleva el contador en el título: sin número no se sabe si hay trabajo', async () => {
    const w = await montar()

    expect(w.find('.mrm__contador').text()).toBe('1')
    expect(w.find('.mrm__pendiente').text()).toContain('Faltó producto')
  })

  it('marcar visto lo saca de la lista y le baja el número a la solapa', async () => {
    const w = await montar()
    await w.find('.mrm__pendiente .mrm__btn').trigger('click')
    await flushPromises()

    expect(revisarTurnoMostrador).toHaveBeenCalledWith(10, 7)
    expect(w.findAll('.mrm__pendiente')).toHaveLength(0)
    expect(w.emitted('sin-revisar').at(-1)).toEqual([0])
  })
})

describe('③ Dónde se va', () => {
  it('arranca por producto y con el % primero, que es el número que manda', async () => {
    const w = await montar()

    expect(w.find('.mrm__table th').text()).toBe('Producto')
    const ths = w.findAll('.mrm__table th').map(t => t.text())
    expect(ths[1]).toBe('%')
    expect(w.find('.mrm__table tbody tr').text()).toContain('Northern Lights')
  })

  // UNA tabla con un corte a la vez, no tres apiladas con las mismas columnas.
  it('cambiar el corte cambia la misma tabla', async () => {
    const w = await montar()
    const botonTurno = w.findAll('.mrm__cortes .mrm__periodo').find(b => b.text() === 'Cierre por cierre')
    await botonTurno.trigger('click')

    expect(w.find('.mrm__table th').text()).toBe('Cerró')
    expect(w.find('.mrm__table tbody tr').text()).toContain('Ana Gómez')
  })

  it('el corte por sede aparece sólo cuando hay más de una', async () => {
    const sinSedes = await montar()
    expect(sinSedes.findAll('.mrm__cortes .mrm__periodo').map(b => b.text())).not.toContain('Por sede')

    const conSedes = await montar({
      por_sede: [{ sede_id: 1, sede: 'Centro', turnos: 4, dispensado: 100, faltante: 5,
                   faltante_ars: 500, merma_pct: 5 }],
    })
    expect(conSedes.findAll('.mrm__cortes .mrm__periodo').map(b => b.text())).toContain('Por sede')
  })

  // Corregir un conteo cerrado ajusta el inventario: vive en el corte por turno, que es donde se
  // mira un cierre concreto.
  it('las acciones de un turno están en su corte, no en el de producto', async () => {
    const w = await montar()
    expect(w.find('.mrm__td-acc').exists()).toBe(false)

    const botonTurno = w.findAll('.mrm__cortes .mrm__periodo').find(b => b.text() === 'Cierre por cierre')
    await botonTurno.trigger('click')
    expect(w.find('.mrm__td-acc').exists()).toBe(true)
  })
})

// EL TABLERO POR PERSONA: para saber dónde ajustar.
//
// El problema de un ranking de gente no es moral, es estadístico: quien más volumen mueve
// encabeza siempre, y quien fracciona flor pierde más que quien entrega prerolls. Por eso cada
// uno va contra el PROMEDIO del mismo mostrador en el mismo período, con su volumen al lado.
describe('Por persona', () => {
  async function abrirCorte () {
    const w = await montar()
    const b = w.findAll('.mrm__cortes .mrm__periodo').find(x => x.text() === 'Por persona')
    await b.trigger('click')
    return w
  }

  it('compara contra el promedio, no contra un número suelto', async () => {
    const w = await abrirCorte()

    expect(w.find('.mrm__table th').text()).toBe('Atendió')
    expect(w.findAll('.mrm__table th').map(t => t.text())).toContain('vs promedio')
    expect(w.find('.mrm__delta').text()).toContain('+4 pts')
  })

  it('muestra el volumen al lado: una fila de un turno no puede gritar igual que una de veinte', async () => {
    const w = await abrirCorte()
    const filas = w.findAll('.mrm__table tbody tr')

    expect(filas[0].text()).toContain('6 cierres')
    expect(filas[0].text()).toContain('6.000')
  })

  // Un +9 pts de alguien con un solo turno es ruido: pintarlo lo convierte en una acusación
  // fundada en nada.
  it('con pocos turnos lo dice y no pinta la diferencia', async () => {
    const w = await abrirCorte()
    const filas = w.findAll('.mrm__table tbody tr')

    expect(filas[1].text()).toContain('Pocos cierres')
    expect(filas[1].find('.mrm__delta').classes()).toContain('is-mudo')
  })

  // Si no, el admin lee el número de alguien que no hizo ese arqueo.
  it('avisa cuando algún turno lo cerró otra persona', async () => {
    const w = await abrirCorte()

    expect(w.findAll('.mrm__table tbody tr')[1].text()).toContain('lo hizo otra persona')
  })

  it('y el CSV se lleva la comparación', async () => {
    const w = await abrirCorte()
    let contenido = ''
    const BlobOriginal = globalThis.Blob
    globalThis.Blob = function (partes, opts) { contenido = partes.join(''); return new BlobOriginal(partes, opts) }
    const urlOriginal = URL.createObjectURL
    URL.createObjectURL = () => 'blob:x'
    URL.revokeObjectURL = () => {}
    // jsdom no navega: sin esto, el click del enlace escribe un error en la salida de otro test.
    const clickOriginal = HTMLAnchorElement.prototype.click
    HTMLAnchorElement.prototype.click = () => {}

    await w.findAll('.mrm__corte .mrm__btn')[0].trigger('click')

    globalThis.Blob = BlobOriginal
    URL.createObjectURL = urlOriginal
    HTMLAnchorElement.prototype.click = clickOriginal
    expect(contenido).toContain('vs promedio')
    expect(contenido).toContain('Ana Gómez')
  })
})

describe('El período', () => {
  // Eran dos campos de fecha y un botón "Ver" para la pregunta que se hace el 95% de las veces.
  it('se elige de un click, sin apretar Ver', async () => {
    const w = await montar()
    getMermaMostrador.mockClear()

    const treinta = w.findAll('.mrm__periodos .mrm__periodo').find(b => b.text() === '30 días')
    await treinta.trigger('click')
    await flushPromises()

    expect(getMermaMostrador).toHaveBeenCalledTimes(1)
    const params = getMermaMostrador.mock.calls[0][1]
    expect(params.desde).toMatch(/^\d{4}-\d{2}-\d{2}$/)
  })

  it('y "Este mes" lo resuelve el backend, que sabe en qué día vive', async () => {
    const w = await montar()
    const treinta = w.findAll('.mrm__periodos .mrm__periodo').find(b => b.text() === '30 días')
    await treinta.trigger('click')
    await flushPromises()
    getMermaMostrador.mockClear()

    const mes = w.findAll('.mrm__periodos .mrm__periodo').find(b => b.text() === 'Este mes')
    await mes.trigger('click')
    await flushPromises()

    expect(getMermaMostrador.mock.calls[0][1].desde).toBe('')
  })
})
