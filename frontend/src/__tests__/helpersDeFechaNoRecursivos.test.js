// Una función que se llama a sí misma con los mismos argumentos no es una función: es un
// «Maximum call stack size exceeded» esperando a que alguien abra la pantalla. Pasó dos veces
// en el mismo barrido (`toISO` en TareasDelLote y `hoyISO` en utils/fecha) y ninguna suite lo
// vio, porque nadie llamaba a esas dos en un test. Esto las llama.
import { describe, it, expect } from 'vitest'
import { hoyISO } from '../utils/fecha.js'
import { hoyISO as hoyDates, toISO } from '../utils/dates.js'

describe('los helpers de fecha contestan', () => {
  it('hoyISO de utils/fecha es el de utils/dates', () => {
    expect(hoyISO()).toBe(hoyDates())
    expect(hoyISO()).toMatch(/^\d{4}-\d{2}-\d{2}$/)
  })

  it('toISO arma la fecha local', () => {
    expect(toISO(new Date(2026, 8, 19, 23, 30))).toBe('2026-09-19')
  })
})
