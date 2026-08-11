import { describe, it, expect } from 'vitest'
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { resolve, dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

// Germán escaneó el QR de una planta en producción y vio una pantalla vacía. En la consola:
// `ReferenceError: usePWA is not defined at setup (PlantaQrView)`. El componente llamaba a
// `usePWA()` sin haberlo importado nunca.
//
// El build NO lo caza: Vite no sabe si `usePWA` es un global del navegador o un olvido, así que
// compila igual y explota recién cuando alguien abre esa pantalla — y sólo esa, porque el error
// está en el setup del componente. Es la misma trampa que las clases CSS sin estilo.
//
// Este test recorre el markup y el script de cada archivo y verifica que todo `useAlgo(` que
// coincida con un composable o store DEL PROYECTO esté importado en ese archivo.
const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), '..')

function archivos(dir, ext = ['.vue', '.js'], acc = []) {
  for (const nombre of readdirSync(dir)) {
    if (nombre === 'node_modules' || nombre === '__tests__') continue
    const ruta = join(dir, nombre)
    if (statSync(ruta).isDirectory()) archivos(ruta, ext, acc)
    else if (ext.some(e => nombre.endsWith(e))) acc.push(ruta)
  }
  return acc
}

// Los nombres que el proyecto define: `useXxx` exportado desde composables/ o stores/.
function propios() {
  const set = new Set()
  for (const dir of ['composables', 'stores']) {
    for (const ruta of archivos(join(RAIZ, dir), ['.js'])) {
      const txt = readFileSync(ruta, 'utf8')
      for (const m of txt.matchAll(/export (?:function|const) (use[A-Z]\w*)/g)) set.add(m[1])
    }
  }
  return set
}

describe('composables y stores usados sin importar', () => {
  const NOMBRES = propios()

  it('el barrido reconoce los composables del proyecto', () => {
    expect(NOMBRES.size).toBeGreaterThan(5)
    expect(NOMBRES.has('usePWA')).toBe(true)
  })

  const fuentes = archivos(join(RAIZ, 'views'))
    .concat(archivos(join(RAIZ, 'components')))
    .concat(archivos(join(RAIZ, 'composables'), ['.js']))

  for (const ruta of fuentes) {
    const rel = relative(RAIZ, ruta)
    it(rel, () => {
      const txt = readFileSync(ruta, 'utf8')
      const usados = new Set([...txt.matchAll(/\b(use[A-Z]\w*)\s*\(/g)].map(m => m[1]))
      const faltan = []

      for (const nombre of usados) {
        if (!NOMBRES.has(nombre)) continue
        // Definido acá mismo (un composable puede llamarse a sí mismo o definir otro).
        if (new RegExp(`(export )?(function|const) ${nombre}\\b`).test(txt)) continue
        if (new RegExp(`import[^;]*\\b${nombre}\\b[^;]*from`).test(txt)) continue
        faltan.push(nombre)
      }

      expect(faltan, `usados sin importar en ${rel} — la pantalla revienta al abrirla`).toEqual([])
    })
  }
})
