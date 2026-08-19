import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const AQUI = dirname(fileURLToPath(import.meta.url))
const SRC  = resolve(AQUI, '..')

// AC: el portal se pinta con TOKENS, no con colores a mano.
//
// Nació de la web vieja y llegó a agosto con 13 pantallas, cero tokens y ocho verdes hardcodeados
// —cuatro de ellos queriendo ser el mismo. El resultado es que cambiar el verde del portal era
// buscar y reemplazar en trece archivos, y que el `theme_primary` que elige cada organización no
// podía aplicarse a nada.
//
// Este test corre con el baseline en CERO desde el día uno: el portal es la única parte de la app
// que no arrastra deuda de color, y la idea es que siga así.
function archivosDelPortal() {
  const dirs = ['views/portal', 'components/portal']
  return dirs.flatMap(d =>
    readdirSync(resolve(SRC, d))
      .filter(f => f.endsWith('.vue'))
      .map(f => [`${d}/${f}`, readFileSync(resolve(SRC, d, f), 'utf8')])
  )
}

/** Sólo el bloque <style>: un hex dentro del script (por ejemplo un fallback calculado) es otra cosa. */
function estilo(src) {
  const m = src.match(/<style[^>]*>([\s\S]*?)<\/style>/)
  return m ? m[1] : ''
}

describe('El portal se pinta con tokens', () => {
  const archivos = archivosDelPortal()

  it('encuentra las pantallas del portal', () => {
    expect(archivos.length).toBeGreaterThan(10)
  })

  for (const [ruta, src] of archivos) {
    it(`${ruta} no tiene colores hardcodeados`, () => {
      const css = estilo(src)

      // Hex de 3 o 6 dígitos. `#fff` y `#000` puros se permiten: son el blanco y el negro
      // absolutos sobre los que se calculan las transparencias, no decisiones de paleta.
      const hex = [...css.matchAll(/#[0-9a-fA-F]{3,8}\b/g)]
        .map(m => m[0].toLowerCase())
        .filter(h => !['#fff', '#ffffff', '#000', '#000000'].includes(h))

      expect(hex, `${ruta}: usá los tokens de design-system/portal.css (--p-*) en vez de ${[...new Set(hex)].join(', ')}`)
        .toEqual([])
    })

    it(`${ruta} usa los íconos del design system, no bootstrap`, () => {
      // El README del DS: `bi-*` no va en pantallas nuevas, y el portal es todo pantalla nueva.
      const bootstrap = [...src.matchAll(/\bbi-[a-z0-9-]+/g)].map(m => m[0])

      expect(bootstrap, `${ruta}: reemplazá ${[...new Set(bootstrap)].join(', ')} por íconos de lucide-vue-next`)
        .toEqual([])
    })
  }
})
