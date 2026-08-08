import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '..')

// Los grises que el proyecto usa de hecho, ya con nombre en tokens.css. Escribirlos otra vez
// a mano no rompe nada hoy, pero es como vuelve la inconsistencia: un archivo con #94a3b8 y
// otro con #93a2b7, y ya nadie puede cambiar el gris de la app en un solo lugar.
const GRISES_CON_TOKEN = {
  '#0f172a': '--c-slate-900', '#334155': '--c-slate-700', '#475569': '--c-slate-600',
  '#64748b': '--c-slate-500', '#94a3b8': '--c-slate-400', '#cbd5e1': '--c-slate-300',
  '#e2e8f0': '--c-slate-200', '#f1f5f9': '--c-slate-100', '#f8fafc': '--c-slate-50',
}

const soloEstilo = (src) => {
  const i = src.indexOf('<style')
  return i === -1 ? '' : src.slice(i)
}

describe('Design system — panel de super admin', () => {
  const dir = resolve(raiz, 'views/superadmin')
  const vistas = readdirSync(dir).filter((f) => f.endsWith('.vue'))

  it('hay vistas para revisar', () => {
    expect(vistas.length).toBeGreaterThan(0)
  })

  for (const archivo of vistas) {
    it(`${archivo}: usa los tokens de gris, no el hexadecimal`, () => {
      const estilo = soloEstilo(readFileSync(resolve(dir, archivo), 'utf8')).toLowerCase()

      const reincidentes = Object.entries(GRISES_CON_TOKEN)
        .filter(([hexa]) => estilo.includes(hexa))
        .map(([hexa, token]) => `${hexa} → var(${token})`)

      expect(reincidentes, `en ${archivo}`).toEqual([])
    })
  }

  it('los tokens de gris existen de verdad en tokens.css', () => {
    const tokens = readFileSync(resolve(raiz, 'design-system/tokens.css'), 'utf8').toLowerCase()

    for (const [hexa, token] of Object.entries(GRISES_CON_TOKEN)) {
      // El alineado de tokens.css usa espacios variables: se compara el par, no el formato.
      expect(tokens, `falta ${token}`).toMatch(new RegExp(`${token}:\\s*${hexa}`))
    }
  })
})
