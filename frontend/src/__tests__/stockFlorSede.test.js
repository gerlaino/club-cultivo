import { describe, it, expect } from 'vitest'
import { resumenStockFlor } from '../lib/stockFlor.js'

// AC (Germán, 7-oct-2026): «cómo puede ser que diga stock bajo en rojo cuando hay muchísimo más».
// Bajo es el total de flor de la sede contra el umbral, no cuántos frascos tienen poco.
const frasco = (g, forma = 'flor_seca') => ({ forma_producto: forma, cantidad: g })

describe('El stock de flor de una sede', () => {
  it('con 3.245 g no está bajo, aunque diez frascos tengan menos de 50 g (el caso de la captura)', () => {
    const stocks = [...Array(10).fill(0).map(() => frasco(20)), ...Array(17).fill(0).map(() => frasco(179.15))]
    const r = resumenStockFlor(stocks, 50)
    expect(Math.round(r.total)).toBe(3246)
    expect(r.bajo).toBe(false)
    expect(r.casiVacios).toBe(10)
  })

  it('está bajo cuando el total no llega al umbral', () => {
    expect(resumenStockFlor([frasco(20), frasco(25)], 50).bajo).toBe(true)
  })

  it('los derivados no suman gramos de flor', () => {
    expect(resumenStockFlor([frasco(500, 'preroll'), frasco(10)], 50)).toMatchObject({ total: 10, bajo: true })
  })

  it('los frascos vacíos no cuentan como «casi vacíos»', () => {
    expect(resumenStockFlor([frasco(0), frasco(30), frasco(400)], 50).casiVacios).toBe(1)
  })
})
