import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// EL HISTORIAL DE ARQUEOS, tal como lo lee administración de un vistazo.
//
// Se rehízo porque no se entendía: decía "faltó 23" sin decir de qué ni en qué unidad, con
// "$27.636,6" al lado sin etiqueta —se leía como el costo de algo— y los números salían con dos
// tipografías distintas en la misma tabla.
//
// El problema de fondo era peor que la presentación: `faltante` SUMA cantidades de unidades
// distintas, así que "23" podían ser 23 g de flor más 4 prerolls. Ese número no significa nada y
// no se puede comparar entre turnos. Los pesos sí.
const TURNO = {
  id: 7, abierto_at: '2026-09-05T17:02:00Z', cerrado_at: '2026-09-05T23:03:00Z',
  atendio: 'Ana Gómez', cerrado_por: 'Ana Gómez', productos: 4, revisado: false,
  dispensado: 120, dispensado_ars: 480000,
  faltante: 23, faltante_ars: 27636.6, productos_con_faltante: 1,
  efectivo_contado_ars: 130000, diferencia_caja_ars: -20000,
}

let respuesta = { turnos: [TURNO], gestiona: true, pagina: 1, paginas: 1, total: 1 }
vi.mock('../lib/api.js', () => ({
  listTurnosMostrador: (...a) => Promise.resolve({ data: respuesta }),
  descargarTurnosMostrador: vi.fn(),
  corregirTurnoMostrador: vi.fn(),
}))

import MostradorTurnos from '../components/mostrador/MostradorTurnos.vue'

async function montar () {
  const w = mount(MostradorTurnos, { props: { sedeId: 10 } })
  await flushPromises()
  return w
}

beforeEach(() => { setActivePinia(createPinia()) })

describe('El historial de arqueos', () => {
  it('mide en PLATA, no en cantidades que suman gramos con unidades', async () => {
    const w = await montar()
    const falto = w.find('[data-col="Faltó"]')

    expect(falto.find('.trn__num').text()).toContain('27.63')
    expect(falto.find('.trn__num').text()).toContain('$')
    // El "23" suelto era 23 g más prerolls: no se muestra más como número principal.
    expect(falto.find('.trn__num').text()).not.toBe('23')
  })

  it('dice EN CUÁNTOS productos faltó, que es lo que un número suelto no dice', async () => {
    const w = await montar()

    expect(w.find('[data-col="Faltó"]').text()).toContain('en 1 producto')
  })

  // Dos cifras pegadas sin decir cuál es cuál: la segunda se leía como el costo de algo.
  it('dice qué es la diferencia de caja, no la deja como un número al lado', async () => {
    const w = await montar()
    const caja = w.find('[data-col="Caja"]')

    expect(caja.find('.trn__num').text()).toContain('130.000')
    expect(caja.text()).toContain('faltó')
    expect(caja.text()).toContain('20.000')
  })

  it('un turno cuadrado lo dice, en vez de mostrar un cero', async () => {
    respuesta = { ...respuesta, turnos: [{ ...TURNO, faltante: 0, faltante_ars: 0, productos_con_faltante: 0 }] }
    const w = await montar()

    expect(w.find('[data-col="Faltó"]').text()).toContain('cuadró')
    respuesta = { ...respuesta, turnos: [TURNO] }
  })

  it('sin nada entregado no inventa un cero: pone un guión', async () => {
    respuesta = { ...respuesta, turnos: [{ ...TURNO, dispensado: 0, dispensado_ars: 0 }] }
    const w = await montar()

    expect(w.find('[data-col="Entregado"]').text()).toBe('—')
    respuesta = { ...respuesta, turnos: [TURNO] }
  })
})
