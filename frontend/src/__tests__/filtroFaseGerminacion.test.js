import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { opcionesFiltroFase, coincideFiltroFase } from '../lib/loteHelpers.js'

// AC (Germán, 30-sep-2026): el filtro por fase dice las mismas palabras que las filas. Filtrar
// «Enraizado» traía filas que decían «Germinación»: el arranque es un estado, dos palabras.
const REGLAS = { arranque_por_origen: { semilla: { estado: 'Germinación' }, esqueje: { estado: 'Enraizado' } } }
const semilla = { estado: 'enraizado', origen: 'semilla' }
const esqueje = { estado: 'enraizado', origen: 'esqueje' }
const vege    = { estado: 'vegetativo', origen: 'semilla' }

describe('Filtro por fase: Germinación y Enraizado', () => {
  it('ofrece «Germinación» y «Enraizado» por separado, con las palabras de /me', () => {
    expect(opcionesFiltroFase(REGLAS, ['enraizado', 'vegetativo', 'floracion']).map(o => o.l))
      .toEqual(['Germinación', 'Enraizado', 'Vegetativo', 'Floración'])
  })

  it('«Germinación» trae sólo las semillas que no fueron a maceta', () => {
    expect([semilla, esqueje, vege].filter(l => coincideFiltroFase(l, 'germinacion'))).toEqual([semilla])
  })

  it('«Enraizado» trae sólo los esquejes (y los viejos sin origen)', () => {
    const viejo = { estado: 'enraizado', origen: null }
    expect([semilla, esqueje, vege, viejo].filter(l => coincideFiltroFase(l, 'enraizado'))).toEqual([esqueje, viejo])
  })

  it('sin filtro trae todo; las demás fases, por su estado', () => {
    expect([semilla, esqueje, vege].filter(l => coincideFiltroFase(l, ''))).toHaveLength(3)
    expect([semilla, esqueje, vege].filter(l => coincideFiltroFase(l, 'vegetativo'))).toEqual([vege])
  })

  it('la sala y la lista de Lotes usan este filtro (no comparan el estado a mano)', () => {
    for (const v of ['views/SalaDetailView.vue', 'views/LotesView.vue']) {
      const src = readFileSync(resolve(__dirname, '..', v), 'utf8')
      expect(src).toContain('coincideFiltroFase')
      expect(src).toContain('opcionesFiltroFase')
    }
  })
})
