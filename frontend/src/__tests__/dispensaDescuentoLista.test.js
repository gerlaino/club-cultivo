import { describe, it, expect } from 'vitest'
import { descuentoPct, descuentoArs } from '../lib/dispensaDescuento.js'

// AC (Germán, 7-oct-2026): «acá no sé por qué figura con descuento del 13%, yo no le puse nada».
// La lista muestra sólo el descuento que alguien cargó; nunca lo deduce del precio.
describe('El descuento que muestra la lista de dispensas', () => {
  it('sin descuento cargado no muestra ninguno, aunque el frasco hoy valga más (el caso del -13%)', () => {
    const d = { descuento_paciente_pct: 0, descuento_dispensa_pct: 0, descuento_dispensa_ars: 0,
                precio_unitario_ars: 10500, stock: { precio_sugerido_ars: 12000 } }
    expect(descuentoPct(d)).toBeNull()
    expect(descuentoArs(d)).toBe(0)
  })

  it('suma el de la ficha del paciente y el de la dispensa', () => {
    expect(descuentoPct({ descuento_paciente_pct: 10, descuento_dispensa_pct: 5 })).toBe(15)
  })

  it('el descuento en pesos se muestra en pesos', () => {
    expect(descuentoArs({ descuento_dispensa_ars: '2600.0' })).toBe(2600)
    expect(descuentoPct({ descuento_dispensa_ars: '2600.0' })).toBeNull()
  })
})
