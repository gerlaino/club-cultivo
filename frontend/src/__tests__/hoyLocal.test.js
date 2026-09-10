import { describe, it, expect, afterEach, vi } from 'vitest'
import { toISO, hoyISO } from '../utils/dates.js'

// "HOY" ES EL DÍA DE QUIEN USA LA APP, NO EL DE UTC.
//
// `new Date().toISOString().slice(0, 10)` devuelve la fecha en UTC. En Argentina (UTC−3) eso da
// el día SIGUIENTE desde las 21:00, y el backend valida la dispensa contra `Time.zone.today` en
// Buenos Aires: entre las 21:00 y la medianoche, dispensar rebotaba con "la fecha no puede ser
// futura" — justo en las horas de más movimiento del dispensario.
//
// Es un bug de tres horas por día: por eso hace falta un test, no probarlo a mano.
describe('hoyISO / toISO', () => {
  afterEach(() => vi.useRealTimers())

  // Las 23:30 del 9 de septiembre en Buenos Aires son las 02:30 del 10 en UTC.
  it('a las 23:30 de Buenos Aires sigue siendo el mismo día, no el siguiente', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-09-09T23:30:00-03:00'))

    expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-10') // lo que hacía antes
    expect(hoyISO()).toBe(toISO(new Date()))
    expect(hoyISO()).toBe(
      `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}-${String(new Date().getDate()).padStart(2, '0')}`,
    )
  })

  it('toISO usa los componentes locales de la fecha que recibe', () => {
    // 31 de diciembre a las 22:00 local: en UTC ya es 1 de enero del año siguiente.
    const nochevieja = new Date(2026, 11, 31, 22, 0, 0)

    expect(toISO(nochevieja)).toBe('2026-12-31')
  })

  it('un string ISO se devuelve tal cual, sin correrse un día', () => {
    expect(toISO('2026-03-01')).toBe('2026-03-01')
  })

  it('sin fecha devuelve vacío', () => {
    expect(toISO(null)).toBe('')
    expect(toISO('cualquier cosa')).toBe('')
  })
})
