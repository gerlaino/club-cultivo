import { describe, it, expect } from 'vitest'
import { formatDateTime } from '../lib/loteHelpers.js'

// AC (recorrido del 20-oct-2026): el historial decía «8 jun, 12:00 a. m.» en lo que se cargó sin hora.
describe('fecha y hora en el historial', () => {
  const anio = new Date().getFullYear()

  it('lo cargado sin hora (medianoche) muestra sólo el día', () => {
    const txt = formatDateTime(new Date(anio, 5, 8, 0, 0))
    expect(txt).toContain('8')
    expect(txt).not.toMatch(/\d{1,2}:\d{2}/)
    expect(txt).not.toMatch(/a\.\s?m\./)
  })

  it('con hora, en formato de 24 horas', () => {
    const txt = formatDateTime(new Date(anio, 5, 8, 14, 30))
    expect(txt).toContain('14:30')
    expect(txt).not.toMatch(/p\.\s?m\./)
  })
})
