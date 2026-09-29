import { describe, it, expect } from 'vitest'
import { estadoLoteLabel, verboArranque, arranquePorOrigen } from '../lib/loteHelpers.js'

// El estado `enraizado` es uno solo para semilla y esqueje; una semilla dice «Germinación»
// (Germán, 29-sep-2026). La palabra la decide el backend: la pantalla la muestra.
describe('estadoLoteLabel', () => {
  it('muestra lo que manda el backend', () => {
    expect(estadoLoteLabel({ estado: 'enraizado', origen: 'semilla', estado_label: 'Germinación' })).toBe('Germinación')
  })
  it('sin estado_label, la palabra del estado (no inventa por el origen)', () => {
    expect(estadoLoteLabel({ estado: 'enraizado', origen: 'semilla' })).toBe('Enraizado')
    expect(estadoLoteLabel({ estado: 'vegetativo' })).toBe('Vegetativo')
  })
  it('el gerundio del arranque también viene del backend', () => {
    expect(verboArranque({ verbo_arranque: 'germinando' })).toBe('germinando')
    expect(verboArranque({})).toBe('enraizando')
  })
})

describe('arranquePorOrigen (alta, sale de /me)', () => {
  const reglas = { arranque_por_origen: {
    semilla: { estado: 'Germinación', verbo: 'germinando', donde: '¿Dónde germina?' },
    esqueje: { estado: 'Enraizado', verbo: 'enraizando', donde: '¿Dónde enraíza?' },
  } }
  it('semilla germina, esqueje enraíza', () => {
    expect(arranquePorOrigen(reglas, 'semilla').donde).toBe('¿Dónde germina?')
    expect(arranquePorOrigen(reglas, 'esqueje').estado).toBe('Enraizado')
  })
  it('sin reglas cargadas cae a enraizado', () => {
    expect(arranquePorOrigen(undefined, 'semilla').estado).toBe('Enraizado')
  })
})
