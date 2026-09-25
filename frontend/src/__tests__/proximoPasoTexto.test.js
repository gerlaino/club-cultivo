import { describe, it, expect } from 'vitest'
import { textoProximoPaso, textoProximoPasoCorto } from '../lib/loteHelpers.js'

// AC (Germán): «Floración venció hace 33 días» no se entiende: no dice contra qué. Acordado:
// «Pasar a floración: tocaba hace 33 días (la genética pide 45 de vege; lleva 78)».
const lote = (paso, extra = {}) => ({ proximo_paso: paso, ...extra })

describe('Próximo paso pasado del objetivo', () => {
  it('dice qué hacer, hace cuánto tocaba, cuánto pide la genética y cuánto lleva', () => {
    const t = textoProximoPaso(lote({ fase: 'floracion', faltan_dias: -33, objetivo_dias: 45, objetivo_origen: 'genetica', lleva_dias: 78 }))
    expect(t).toBe('Pasar a floración: tocaba hace 33 días (la genética pide 45 de vege; lleva 78)')
  })

  it('si el número lo cambiaron en el lote, no se lo atribuye a la genética', () => {
    const t = textoProximoPaso(lote({ fase: 'floracion', faltan_dias: -5, objetivo_dias: 50, objetivo_origen: 'lote', lleva_dias: 55 }))
    expect(t).toContain('el plan del lote pide 50 de vege')
    expect(t).not.toContain('genética')
  })

  it('en floración habla de cosechar y de días de floración', () => {
    const t = textoProximoPaso(lote({ fase: 'cosecha', faltan_dias: -1, objetivo_dias: 60, objetivo_origen: 'genetica', lleva_dias: 61 }))
    expect(t).toBe('Cosechar: tocaba hace 1 día (la genética pide 60 de floración; lleva 61)')
  })

  it('una automática habla del ciclo', () => {
    const t = textoProximoPaso(lote({ fase: 'cosecha', faltan_dias: -3, objetivo_dias: 70, objetivo_origen: 'genetica', lleva_dias: 73, automatica: true }, { dias_ciclo_objetivo: 70 }))
    expect(t).toContain('la genética pide un ciclo de 70; lleva 73')
  })

  it('con fecha de cosecha fijada a mano lo dice así', () => {
    const t = textoProximoPaso(lote({ fase: 'cosecha', fecha: '2026-09-10', faltan_dias: -4, objetivo_dias: null, objetivo_origen: 'fecha_estimada', lleva_dias: 64 }))
    expect(t).toContain('Cosechar: tocaba hace 4 días (cosecha estimada para el 10/9')
  })

  it('en la tabla, corto y como acción: no «Cosecha hace 32 d», que parece que ya se cosechó', () => {
    const t = textoProximoPasoCorto(lote({ fase: 'cosecha', faltan_dias: -32 }))
    expect(t).toBe('Cosechar · tocaba hace 32 d')
  })

  it('lo que todavía no toca sigue igual', () => {
    expect(textoProximoPaso(lote({ fase: 'floracion', faltan_dias: 8 }))).toBe('Faltan 8 días para floración')
    expect(textoProximoPasoCorto(lote({ fase: 'floracion', faltan_dias: 8 }))).toBe('Flora en 8 d')
  })
})
