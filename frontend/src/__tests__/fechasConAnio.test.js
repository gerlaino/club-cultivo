// AC (Germán, 20-oct-2026): una fecha de otro año dice el año. «2 dic» de hace diez meses se leía
// como el diciembre que viene.
import { describe, it, expect, vi, afterEach } from 'vitest'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { fechaLocal } from '../utils/dates.js'

const CORTA = { day: 'numeric', month: 'short' }

describe('fechaLocal', () => {
  afterEach(() => vi.useRealTimers())

  it('de este año, sin año', () => {
    vi.useFakeTimers({ now: new Date(2026, 9, 20) })
    expect(fechaLocal(new Date(2026, 1, 3), CORTA)).not.toMatch(/2026/)
  })

  it('de otro año, con el año (para atrás y para adelante)', () => {
    vi.useFakeTimers({ now: new Date(2026, 9, 20) })
    expect(fechaLocal(new Date(2025, 11, 2), CORTA)).toMatch(/2025/)
    expect(fechaLocal(new Date(2027, 0, 5), CORTA)).toMatch(/2027/)
  })

  it('una fecha inválida no dibuja «Invalid Date»', () => {
    expect(fechaLocal('no-es-fecha', CORTA)).toBe('')
  })
})

// El barrido: ninguna pantalla arma una fecha corta (día + mes) por su cuenta. Si aparece una nueva
// sin pasar por `fechaLocal`, vuelve el «2 dic» sin año.
describe('ninguna pantalla arma «día + mes» sin fechaLocal', () => {
  const src = join(process.cwd(), 'src') + '/'
  const archivos = []
  const recorrer = (d) => readdirSync(d).forEach((n) => {
    const p = join(d, n)
    if (statSync(p).isDirectory()) { if (n !== '__tests__') recorrer(p) } else if (/\.(vue|js)$/.test(n)) archivos.push(p)
  })
  recorrer(src)

  it('barre src', () => {
    const malos = []
    const re = /\.toLocale(?:Date)?String\('es-AR',\s*(\{[^{}]*\})\)/g
    for (const p of archivos) {
      if (p.endsWith('utils/dates.js')) continue
      for (const m of readFileSync(p, 'utf8').matchAll(re)) {
        const o = m[1]
        if (o.includes("month: 'short'") && o.includes('day') && !o.includes('year')) malos.push(`${p.replace(src, '')}: ${o}`)
      }
    }
    expect(malos).toEqual([])
  })
})
