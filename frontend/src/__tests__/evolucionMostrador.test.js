import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// LO QUE TENÍA QUE HABER CONTRA LO QUE SE CONTÓ, PRODUCTO POR PRODUCTO.
//
// Idea de Germán: «se hace una línea por cada producto de stock». Resuelve el problema de fondo —
// un total tendría que sumar gramos de flor con unidades de preroll, y eso no significa nada.
//
// Y CADA UNO CON SU ESCALA, que es lo que decide el diseño. Los dos casos:
//   · EL DESPLOME — 23 g de golpe. Se ve en cualquier gráfico.
//   · EL GOTEO — un gramo casi todos los días. En un eje compartido con la flor a 400 g no
//     existe, y es el que sangra sin disparar ninguna alarma.

const KUSH = {
  stock_id: 1, etiqueta: 'Critical Kush L-26-017', unidad: 'g', falta: 23, falta_ars: 27636,
  sin_diferencias: false, peor: { fecha: '2026-09-08', falta: 23 },
  puntos: [
    { fecha: '2026-09-05', esperado: 46, contado: 46 },
    { fecha: '2026-09-06', esperado: 46, contado: 46 },
    { fecha: '2026-09-07', esperado: 46, contado: 46 },
    { fecha: '2026-09-08', esperado: 46, contado: 23 },
  ],
}
const NORTHERN = {
  stock_id: 2, etiqueta: 'Northern Lights L-26-001', unidad: 'g', falta: 4, falta_ars: 4600,
  sin_diferencias: false, peor: { fecha: '2026-09-06', falta: 2 },
  puntos: [
    { fecha: '2026-09-05', esperado: 120, contado: 119 },
    { fecha: '2026-09-06', esperado: 120, contado: 118 },
    { fecha: '2026-09-07', esperado: 120, contado: 120 },
    { fecha: '2026-09-08', esperado: 120, contado: 119 },
  ],
}
const PREROLL = {
  stock_id: 3, etiqueta: 'Preroll 0,5 g', unidad: 'u', falta: 0, falta_ars: 0,
  sin_diferencias: true, peor: null,
  puntos: [
    { fecha: '2026-09-05', esperado: 12, contado: 12 },
    { fecha: '2026-09-08', esperado: 12, contado: 12 },
  ],
}

let respuesta = { desde: '2026-09-01', hasta: '2026-09-08', productos: [KUSH, NORTHERN, PREROLL] }
const getEvolucionMostrador = vi.fn(() => Promise.resolve({ data: respuesta }))
vi.mock('../lib/api.js', () => ({
  getEvolucionMostrador: (...a) => getEvolucionMostrador(...a),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

import EvolucionMostrador from '../components/mostrador/EvolucionMostrador.vue'

async function montar (productos) {
  if (productos) respuesta = { ...respuesta, productos }
  const w = mount(EvolucionMostrador, { props: { sedeId: 10 } })
  await flushPromises()
  return w
}

const fichas = (w) => w.findAll('.evo__mini')
// Los puntos de una polilínea, como pares de números.
const pts = (poly) => poly.attributes('points').trim().split(/\s+/).map(p => p.split(',').map(Number))

beforeEach(() => {
  respuesta = { desde: '2026-09-01', hasta: '2026-09-08', productos: [KUSH, NORTHERN, PREROLL] }
  getEvolucionMostrador.mockClear()
})

describe('Un gráfico por producto', () => {
  it('dibuja uno por cada producto con diferencias, y pliega los que cuadran', async () => {
    const w = await montar()

    expect(fichas(w)).toHaveLength(2)
    expect(w.text()).toContain('Critical Kush')
    expect(w.text()).toContain('Northern Lights')
    expect(w.text()).not.toContain('Preroll')
    expect(w.find('.evo__mas').text()).toContain('1 producto más')
  })

  it('los que cuadran se despliegan si se los pide', async () => {
    const w = await montar()
    await w.find('.evo__mas').trigger('click')

    expect(w.text()).toContain('Preroll')
    expect(w.text()).toContain('está todo')
  })

  it('cada ficha lleva dos series: lo que tenía que haber y lo que se contó', async () => {
    const w = await montar()
    expect(fichas(w)[0].findAll('polyline')).toHaveLength(2)
  })
})

// ── LA ESCALA PROPIA, que es toda la decisión ──────────────────────────────────────
describe('Cada producto en su escala', () => {
  it('el goteo de 1 g se dibuja tan alto como el desplome de 23', async () => {
    const w = await montar()
    const alto = (ficha) => {
      const p = pts(ficha.findAll('polyline')[1])   // la serie de lo contado
      const ys = p.map(([, y]) => y)
      return Math.max(...ys) - Math.min(...ys)
    }

    // Northern pierde 1-2 g sobre 120; Kush se desploma 23 sobre 46. En un eje compartido la
    // primera sería una línea plana. Acá las dos usan casi todo el alto de su ficha.
    expect(alto(fichas(w)[0])).toBeGreaterThan(30)
    expect(alto(fichas(w)[1])).toBeGreaterThan(30)
  })

  it('un producto que nunca se movió no revienta la escala', async () => {
    const w = await montar([{ ...KUSH, falta: 0, sin_diferencias: false, peor: null,
      puntos: [{ fecha: '2026-09-05', esperado: 46, contado: 46 },
               { fecha: '2026-09-08', esperado: 46, contado: 46 }] }])

    const ys = pts(fichas(w)[0].findAll('polyline')[1]).map(([, y]) => y)
    expect(ys.every(y => Number.isFinite(y))).toBe(true)
  })

  it('con un solo día tampoco', async () => {
    const w = await montar([{ ...KUSH, puntos: [{ fecha: '2026-09-08', esperado: 46, contado: 23 }] }])
    const ys = pts(fichas(w)[0].findAll('polyline')[1]).map(([, y]) => y)
    expect(ys.every(y => Number.isFinite(y))).toBe(true)
  })
})

describe('Qué cuenta cada ficha', () => {
  it('el titular dice cuánto falta y cuándo fue peor', async () => {
    const w = await montar()
    const t = fichas(w)[0].find('.evo__mini-n').text()

    expect(t).toContain('23')
    // El formato del día depende del Intl del entorno (jsdom da «8/9», el navegador «08/09»):
    // lo que se prueba es que la fecha esté, no cómo la escribe la plataforma.
    expect(t).toMatch(/0?8\/0?9/)
  })

  it('marca el peor día, que es adónde va el ojo', async () => {
    const w = await montar()
    expect(fichas(w)[0].findAll('circle')).toHaveLength(1)
  })

  it('y el gráfico se describe para quien no lo ve', async () => {
    const w = await montar()
    const alt = fichas(w)[0].find('svg').attributes('aria-label')

    expect(alt).toContain('Critical Kush')
    expect(alt).toContain('23')
  })
})

describe('El período', () => {
  it('lo resuelve el backend, que sabe en qué día vive', async () => {
    await montar()
    expect(getEvolucionMostrador).toHaveBeenCalledWith(10, { desde: '', hasta: '' })
  })

  it('y los campos quedan con el rango que usó', async () => {
    const w = await montar()
    expect(w.findAll('.evo__inp')[0].element.value).toBe('2026-09-01')
  })
})
