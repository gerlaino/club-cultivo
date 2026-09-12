import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'

// LO QUE TENÍA QUE HABER CONTRA LO QUE SE CONTÓ, PARA UN FRASCO.
//
// Idea de Germán: «se hace una línea por cada producto de stock». Resuelve el problema de fondo —
// un total tendría que sumar gramos de flor con unidades de preroll, y eso no significa nada.
//
// Y CADA UNO CON SU ESCALA, que es lo que decide el diseño. Los dos casos:
//   · EL DESPLOME — 23 g de golpe. Se ve en cualquier gráfico.
//   · EL GOTEO — un gramo casi todos los días. En un eje compartido con la flor a 400 g no
//     existe, y es el que sangra sin disparar ninguna alarma.
//
// Vivía en una solapa propia («Producto por producto»); ahora es el detalle de cada fila de
// Merma (ver `mostradorMerma.test.js`). El dibujo es el mismo y estas pruebas lo cuidan.
import GraficoProducto from '../components/mostrador/GraficoProducto.vue'

const KUSH = {
  stock_id: 1, etiqueta: 'Critical Kush (flor seca)', numero: 'ST-26-017', unidad: 'g', falta: 23, falta_ars: 27636,
  sin_diferencias: false, peor: { fecha: '2026-09-08', falta: 23 },
  puntos: [
    { fecha: '2026-09-05', esperado: 46, contado: 46 },
    { fecha: '2026-09-06', esperado: 46, contado: 46 },
    { fecha: '2026-09-07', esperado: 46, contado: 46 },
    { fecha: '2026-09-08', esperado: 46, contado: 23 },
  ],
}
const NORTHERN = {
  stock_id: 2, etiqueta: 'Northern Lights (flor seca)', numero: 'ST-26-001', unidad: 'g', falta: 4, falta_ars: 4600,
  sin_diferencias: false, peor: { fecha: '2026-09-06', falta: 2 },
  puntos: [
    { fecha: '2026-09-05', esperado: 120, contado: 119 },
    { fecha: '2026-09-06', esperado: 120, contado: 118 },
    { fecha: '2026-09-07', esperado: 120, contado: 120 },
    { fecha: '2026-09-08', esperado: 120, contado: 119 },
  ],
}

const montar = (producto) => mount(GraficoProducto, { props: { producto } })
// Los puntos de una polilínea, como pares de números.
const pts = (poly) => poly.attributes('points').trim().split(/\s+/).map(p => p.split(',').map(Number))
const altoDe = (w) => {
  const ys = pts(w.findAll('polyline')[1]).map(([, y]) => y)   // la serie de lo contado
  return Math.max(...ys) - Math.min(...ys)
}

describe('Cada frasco en su escala', () => {
  it('el goteo de 1 g se dibuja tan alto como el desplome de 23', () => {
    // Northern pierde 1-2 g sobre 120; Kush se desploma 23 sobre 46. En un eje compartido la
    // primera sería una línea plana. Acá las dos usan casi todo el alto de su ficha.
    expect(altoDe(montar(KUSH))).toBeGreaterThan(30)
    expect(altoDe(montar(NORTHERN))).toBeGreaterThan(30)
  })

  it('lleva dos series: lo que tenía que haber y lo que se contó', () => {
    expect(montar(KUSH).findAll('polyline')).toHaveLength(2)
  })

  it('un frasco que nunca se movió no revienta la escala', () => {
    const w = montar({ ...KUSH, falta: 0, peor: null,
      puntos: [{ fecha: '2026-09-05', esperado: 46, contado: 46 },
               { fecha: '2026-09-08', esperado: 46, contado: 46 }] })
    const ys = pts(w.findAll('polyline')[1]).map(([, y]) => y)
    expect(ys.every(y => Number.isFinite(y))).toBe(true)
  })

  it('con un solo día tampoco', () => {
    const w = montar({ ...KUSH, puntos: [{ fecha: '2026-09-08', esperado: 46, contado: 23 }] })
    const ys = pts(w.findAll('polyline')[1]).map(([, y]) => y)
    expect(ys.every(y => Number.isFinite(y))).toBe(true)
  })
})

describe('Qué cuenta la ficha', () => {
  it('el titular dice el frasco, cuánto falta y cuándo fue peor', () => {
    const w = montar(KUSH)
    expect(w.text()).toContain('ST-26-017')
    const t = w.find('.gpr__n').text()
    expect(t).toContain('23')
    // El formato del día depende del Intl del entorno (jsdom da «8/9», el navegador «08/09»).
    expect(t).toMatch(/0?8\/0?9/)
  })

  it('marca el peor día, que es adónde va el ojo', () => {
    expect(montar(KUSH).findAll('circle')).toHaveLength(1)
  })

  it('uno que cuadra lo dice y no pinta ningún hueco', () => {
    const w = montar({ ...KUSH, falta: 0, sin_diferencias: true, peor: null })
    expect(w.text()).toContain('está todo')
    expect(w.find('polygon').exists()).toBe(false)
  })

  it('y el gráfico se describe para quien no lo ve', () => {
    const alt = montar(KUSH).find('svg').attributes('aria-label')
    expect(alt).toContain('Critical Kush')
    expect(alt).toContain('23')
  })
})
