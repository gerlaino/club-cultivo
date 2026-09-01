import { describe, it, expect } from 'vitest'
import { unidadDe } from '../lib/formatters.js'

// El alta de stock mandaba SIEMPRE `unidad: 'g'`. Agregar "Preroll" al desplegable no alcanzaba:
// se creaban "100 g de preroll" en vez de 100 unidades, y ese registro no sirve para nada —
// el dispensador ve gramos de algo que se entrega por unidad.
describe('La unidad la manda la forma del producto', () => {
  it('lo que se cuenta por unidad', () => {
    expect(unidadDe('preroll')).toBe('un')
    expect(unidadDe('capsula')).toBe('un')
    expect(unidadDe('comestible')).toBe('un')
  })

  it('lo que se mide en volumen', () => {
    expect(unidadDe('aceite')).toBe('ml')
    expect(unidadDe('tintura')).toBe('ml')
  })

  it('el resto, en gramos', () => {
    expect(unidadDe('flor_seca')).toBe('g')
    expect(unidadDe('hash')).toBe('g')
    expect(unidadDe('prensado')).toBe('g')
  })

  // Una forma que no esté en la tabla no puede romper el alta.
  it('lo desconocido cae en gramos, no en undefined', () => {
    expect(unidadDe('lo_que_sea')).toBe('g')
    expect(unidadDe(null)).toBe('g')
  })
})
