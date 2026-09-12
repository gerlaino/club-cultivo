import { describe, it, expect } from 'vitest'
import { textoCambioDeFase } from '../lib/textoCambioDeFase.js'

// EL GUARD al dar vuelta una sala con lotes adentro. Ida y vuelta no son simétricas: volver a
// vegetativo DESHACE el paso a floración, y el texto tiene que decir exactamente qué se borra y
// qué queda — lote por lote, con los días.
const VUELTA = {
  deshace: true, tareas_a_cancelar: 4,
  lotes_afectados: [
    { codigo: 'L-26-017', genetica: 'Fruti Punchi', dias_en_fase: 3, plantas: 24, estado_actual: 'floracion', estado_nuevo: 'vegetativo' },
    { codigo: 'L-26-021', genetica: 'Gelato',       dias_en_fase: 1, plantas: 12, estado_actual: 'floracion', estado_nuevo: 'vegetativo' },
  ],
}

describe('Volver a vegetativo', () => {
  it('titula como lo que es: deshacer', () => {
    const t = textoCambioDeFase(VUELTA)
    expect(t.title).toBe('Estos lotes vuelven a vegetativo como si nunca hubieran pasado a floración')
    expect(t.confirmText).toBe('Volver a vegetativo')
  })

  it('nombra cada lote con sus días en floración y sus plantas', () => {
    const m = textoCambioDeFase(VUELTA).message
    expect(m).toContain('L-26-017 Fruti Punchi — 3 días en floración, 24 plantas')
    expect(m).toContain('L-26-021 Gelato — 1 día en floración, 12 plantas')
  })

  it('dice qué se borra y qué queda', () => {
    const m = textoCambioDeFase(VUELTA).message
    expect(m).toContain('Se borra su paso a floración (esos días no cuentan en el ciclo) y se cancelan 4 tareas de floración pendientes.')
    expect(m).toContain('Las fotos, notas y riegos de esos días quedan.')
    expect(m).not.toMatch(/toda la información/i)
  })

  it('sin tareas pendientes no las menciona', () => {
    const m = textoCambioDeFase({ ...VUELTA, tareas_a_cancelar: 0 }).message
    expect(m).toContain('Se borra su paso a floración (esos días no cuentan en el ciclo).')
    expect(m).not.toContain('tarea')
  })

  it('con un solo lote habla en singular', () => {
    const t = textoCambioDeFase({ ...VUELTA, lotes_afectados: VUELTA.lotes_afectados.slice(0, 1) })
    expect(t.title).toBe('Este lote vuelve a vegetativo como si nunca hubiera pasado a floración')
  })
})

describe('Pasar a floración', () => {
  const IDA = { deshace: false, lotes_afectados: [{ codigo: 'L-26-030', genetica: 'Gelato', dias_en_fase: 2, plantas: 10 }] }

  // El error humano es simétrico: pasar a 12/12 un lote recién trasplantado también es un error.
  it('dice los días que lleva en vegetativo y que no se deshace gratis', () => {
    const t = textoCambioDeFase(IDA)
    expect(t.title).toBe('Pasar la sala a floración cambia de fase a 1 lote')
    expect(t.message).toContain('L-26-030 Gelato — 2 días en vegetativo, 10 plantas')
    expect(t.message).toContain('la planta ya recibió 12/12')
    expect(t.confirmText).toBe('Pasar a floración')
  })
})
