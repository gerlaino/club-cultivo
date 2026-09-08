import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// LA SOLAPA DE MERMA: UNA LÍNEA Y UNA LISTA.
//
// Germán, mirándola en producción: "sigue sin ser intuitiva, simple, sencilla... lo siento sucio,
// con ruido". Tenía razón, y el diagnóstico fue que había más texto explicando la pantalla que
// datos en la pantalla — dos frases largas defendiendo el orden de una tabla y el nombre de una
// sección.
//
// Tres cosas cambiaron y las tres se prueban acá:
//   ① EL NÚMERO PRIMERO. El cuadro arrancaba diciendo «con ese volumen el porcentaje no dice
//      nada» con los $27.636 que faltaban abajo, en gris. La pantalla muda encima del único dato.
//   ② «PARA MIRAR» SE MUDÓ A CIERRES. Era la misma lista de cierres, filtrada, en otra solapa.
//   ③ LA TABLA DE 5 COLUMNAS SE FUE. «% · vs promedio · Faltó · A costo · Entregado» eran cinco
//      números sin sujeto —Germán preguntó qué era «Entregado»— y con la mesa parada TODAS las
//      celdas decían «–%». Ahora manda la plata, que existe siempre y se compara entre productos.

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
  // EL HECHO PRIMERO. Lo que se lee al entrar es cuánto falta, no un veredicto sobre si el
  // porcentaje es calculable.
  it('el titular arranca por la plata que falta', async () => {
    const w = await montar()
    expect(w.find('.mrm__estado-frase').text()).toBe('Faltaron $9.000 en 9 cierres.')
  })

  it('cuando cuadró lo dice, en vez de no decir nada', async () => {
    const w = await montar({ resumen: { ...BASE.resumen, faltante: 0, faltante_ars: 0 } })
    expect(w.find('.mrm__estado-frase').text()).toContain('Cuadró todo')
  })

  // Este es el caso de la captura: se entregó 0, así que no hay porcentaje. Antes el titular
  // decía «con ese volumen el porcentaje no dice nada» ENCIMA de los pesos faltantes.
  it('sin volumen para comparar, el número sigue primero y la advertencia va abajo', async () => {
    const w = await montar({ veredicto: { ...BASE.veredicto, estado: 'poco_volumen', motor: null } })

    expect(w.find('.mrm__estado-frase').text()).toContain('$9.000')
    expect(w.find('.mrm__estado-sub').text()).toContain('poco volumen')
  })

  // Un porcentaje solo no dice nada: lo que importa es que CAMBIÓ respecto del patrón de acá.
  it('la comparación contra el historial va debajo, con los dos números', async () => {
    const w = await montar()
    const sub = w.find('.mrm__estado-sub').text()
    expect(sub).toContain('5.1%')
    expect(sub).toContain('1.2%')
    expect(sub).toContain('8 semanas')
  })

  it('y dice qué producto la está moviendo', async () => {
    const w = await montar()
    expect(w.text()).toContain('Northern Lights')
  })

  it('cuando está como siempre no inventa una alarma', async () => {
    const w = await montar({
      veredicto: { ...BASE.veredicto, estado: 'normal', motor: null, pct: 1.1, pct_previo: 1.2 },
    })
    expect(w.find('.mrm__estado').classes()).toContain('mrm__estado--ok')
  })

  it('dibuja la tendencia semana a semana', async () => {
    const w = await montar()
    expect(w.findAll('.mrm__barra')).toHaveLength(2)
  })
})

// ② «Para mirar» ya no vive acá: es un filtro de la solapa Cierres, que es donde están los
// cierres. Tenerlo en los dos lados eran dos listas de lo mismo con distinto nombre.
describe('② La lista de trabajo se mudó a Cierres', () => {
  it('la solapa de merma ya no la muestra', async () => {
    const w = await montar()
    expect(w.find('.mrm__pendiente').exists()).toBe(false)
    expect(w.text()).not.toContain('Para mirar')
  })

  it('ni ofrece corregir un cierre: eso se hace donde se lo mira', async () => {
    const w = await montar()
    expect(w.text()).not.toContain('Corregir conteo')
    expect(w.findAll('.mrm__cortes .mrm__periodo').map(b => b.text()))
      .not.toContain('Cierre por cierre')
  })
})

describe('③ Dónde se va', () => {
  const filas = (w) => w.findAll('.mrm__fila')

  it('arranca por producto, con la plata adelante y el resto en castellano', async () => {
    const w = await montar()

    expect(filas(w)).toHaveLength(1)
    expect(filas(w)[0].find('.mrm__fila-titulo').text()).toContain('Northern Lights')
    expect(filas(w)[0].find('.mrm__fila-ars').text()).toBe('$5.000')
    expect(filas(w)[0].find('.mrm__fila-sub').text()).toContain('sobre 1.000 g entregados (5%)')
  })

  // EL HALLAZGO QUE LA TABLA VIEJA NO SABÍA DECIR: faltar producto de algo que no se vendió no es
  // merma, es producto que desapareció. Y era una fila entera de «–%» y «0 g».
  it('si no se entregó nada, lo dice en vez de mostrar un porcentaje vacío', async () => {
    const w = await montar({
      por_producto: [{ producto: 'Critical Kush — L-26-017 (flor seca)', unidad: 'g',
                       dispensado: 0, faltante: 23, faltante_ars: 27636, merma_pct: null, turnos: 2 }],
    })

    const sub = filas(w)[0].find('.mrm__fila-sub').text()
    expect(sub).toContain('no se entregó nada')
    expect(sub).not.toContain('%')
  })

  // Ordenar por porcentaje no servía: desaparece cuando no se vendió. La plata existe siempre.
  it('ordena por plata, de mayor a menor', async () => {
    const w = await montar({
      por_producto: [
        { producto: 'Poco', unidad: 'g', dispensado: 100, faltante: 1, faltante_ars: 500, merma_pct: 1, turnos: 1 },
        { producto: 'Mucho', unidad: 'g', dispensado: 100, faltante: 9, faltante_ars: 9000, merma_pct: 9, turnos: 1 },
      ],
    })

    expect(filas(w).map(f => f.find('.mrm__fila-titulo').text())).toEqual(['Mucho', 'Poco'])
  })

  it('no lista lo que no se fue a ningún lado', async () => {
    const w = await montar({
      por_producto: [
        { producto: 'Cuadró', unidad: 'g', dispensado: 500, faltante: 0, faltante_ars: 0, merma_pct: 0, turnos: 2 },
        { producto: 'Faltó', unidad: 'g', dispensado: 500, faltante: 5, faltante_ars: 900, merma_pct: 1, turnos: 2 },
      ],
    })

    expect(filas(w).map(f => f.find('.mrm__fila-titulo').text())).toEqual(['Faltó'])
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
})

// EL CORTE POR PERSONA: para saber dónde ajustar.
//
// El problema de un ranking de gente no es moral, es estadístico: quien más volumen mueve
// encabeza siempre. Por eso lo que evita leerlo mal —el volumen, la comparación contra el
// promedio de acá, y si son pocos cierres— va EN LA MISMA LÍNEA, no en tres columnas y un chip.
describe('Por persona', () => {
  async function abrirCorte (extra) {
    const w = await montar(extra)
    const b = w.findAll('.mrm__cortes .mrm__periodo').find(x => x.text() === 'Por persona')
    await b.trigger('click')
    return w
  }

  it('compara contra el promedio de acá, con el volumen al lado', async () => {
    const w = await abrirCorte()
    const sub = w.findAll('.mrm__fila')[0].find('.mrm__fila-sub').text()

    expect(sub).toContain('6 cierres')
    expect(sub).toContain('6.000')
    expect(sub).toContain('+4 pts contra el promedio')
  })

  // Un +9 pts de alguien con un solo cierre es ruido: darlo por bueno sería una conclusión
  // fundada en nada.
  it('con pocos cierres no concluye', async () => {
    const w = await abrirCorte()
    const sub = w.findAll('.mrm__fila')[1].find('.mrm__fila-sub').text()

    expect(sub).toContain('pocos cierres para concluir')
    expect(sub).not.toContain('pts')
  })

  // Si no, el admin lee el número de alguien que no hizo ese arqueo.
  it('avisa cuando algún cierre lo hizo otra persona', async () => {
    const w = await abrirCorte()
    expect(w.findAll('.mrm__fila')[1].find('.mrm__fila-sub').text()).toContain('otra persona')
  })

  it('y el CSV se lleva el contexto entero', async () => {
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
    expect(contenido).toContain('Ana Gómez')
    expect(contenido).toContain('contra el promedio')
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
