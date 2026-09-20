import { describe, it, expect } from 'vitest'
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join } from 'node:path'

// Dos veces el mismo bug (10-sep en la ficha del lote, 20-sep en las tareas del teléfono): un
// helper local escrito como `function toISO(d) { return toISO(d) }` —la sombra de un import
// que se olvidó—. Compila, ESLint no lo ve, y la pantalla explota al abrirse con «Maximum call
// stack size exceeded». Este test barre todo `src` buscando exactamente esa forma.
function archivos(dir, out = []) {
  for (const n of readdirSync(dir)) {
    const p = join(dir, n)
    if (statSync(p).isDirectory()) { if (!/node_modules|__tests__/.test(p)) archivos(p, out) }
    else if (/\.(vue|js)$/.test(n)) out.push(p)
  }
  return out
}

const RE = /function\s+(\w+)\s*\(([^)]*)\)\s*\{\s*return\s+(\w+)\s*\(/g

describe('ninguna función es sólo una llamada a sí misma', () => {
  it('no hay `function x() { return x(...) }` en src', () => {
    const hallazgos = []
    for (const f of archivos(join(process.cwd(), 'src'))) {
      const s = readFileSync(f, 'utf8')
      for (const m of s.matchAll(RE)) if (m[1] === m[3]) hallazgos.push(`${f.replace(process.cwd() + '/', '')}: ${m[1]}`)
    }
    expect(hallazgos, 'estas funciones se llaman a sí mismas y explotan al usarse').toEqual([])
  })
})
