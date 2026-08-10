import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { resolve, dirname, join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import baseline from './clasesSinEstilo.baseline.json'

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '..')

// Un template puede nombrar clases que nadie definió y Vite compila igual, feliz. Ya pasó tres
// veces: el modal contable salió sin estilos, y los botones de "Método de aplicación" del
// registro de sala se veían como <button> crudos del navegador en medio de un formulario
// entero estilado.
//
// El baseline congela las que ya estaban el día que se puso este test. No son todas bugs —
// muchas son marcadores semánticos o nombres de <transition>, que no necesitan estilo— y
// distinguirlas exige mirar cada pantalla renderizada. Lo que este test garantiza es que la
// lista NO CREZCA: cualquier clase nueva sin estilo rompe acá, antes de llegar a producción.
//
// Al arreglar una, hay que sacarla del baseline. Es a propósito: la lista sólo puede achicarse.

function archivosVue(dir) {
  const out = []
  for (const nombre of readdirSync(dir)) {
    const ruta = join(dir, nombre)
    if (statSync(ruta).isDirectory()) out.push(...archivosVue(ruta))
    else if (nombre.endsWith('.vue')) out.push(ruta)
  }
  return out
}

// Lo definido en CSS global también cuenta: no todo estilo vive en el <style scoped>.
function clasesGlobales() {
  const out = new Set()
  const buscar = (dir) => {
    for (const nombre of readdirSync(dir)) {
      const ruta = join(dir, nombre)
      if (statSync(ruta).isDirectory()) buscar(ruta)
      else if (nombre.endsWith('.css')) {
        for (const m of readFileSync(ruta, 'utf8').matchAll(/\.([a-zA-Z0-9_-]+)/g)) out.add(m[1])
      }
    }
  }
  buscar(raiz)
  return out
}

const GLOBALES = clasesGlobales()

function huerfanasDe(ruta) {
  const src = readFileSync(ruta, 'utf8')
  if (!src.includes('<style')) return []

  const markup = src.replace(/<script[\s\S]*?<\/script>/g, '').replace(/<style[\s\S]*?<\/style>/g, '')
  const definidas = new Set([...src.slice(src.indexOf('<style')).matchAll(/\.([a-zA-Z0-9_-]+)/g)].map((m) => m[1]))

  const usadas = new Set()
  // Sólo clases BEM del propio componente (llevan __ o --). Las utilidades de Bootstrap y las
  // globales quedan afuera por el filtro y por GLOBALES.
  for (const m of markup.matchAll(/(?<!:)\bclass="([^"]*)"/g)) {
    for (const c of m[1].split(/\s+/)) if (c.includes('__') || c.includes('--')) usadas.add(c)
  }
  for (const m of markup.matchAll(/:class="([^"]*)"/g)) {
    for (const c of m[1].matchAll(/'([^']+)'/g)) {
      if (c[1].includes('__') || c[1].includes('--')) usadas.add(c[1])
    }
  }

  return [...usadas].filter((c) => !definidas.has(c) && !GLOBALES.has(c)).sort()
}

describe('Clases CSS que el template usa y nadie definió', () => {
  const vues = archivosVue(raiz)

  it('hay componentes para revisar', () => {
    expect(vues.length).toBeGreaterThan(100)
  })

  for (const ruta of vues) {
    const rel = relative(raiz, ruta).replace(/\\/g, '/')
    const conocidas = new Set(baseline[rel] || [])

    it(`${rel}`, () => {
      const nuevas = huerfanasDe(ruta).filter((c) => !conocidas.has(c))

      expect(nuevas, `clases sin estilo en ${rel} — definilas en su <style>`).toEqual([])
    })
  }

  // Si arreglaste una y no la sacaste del baseline, el candado queda flojo sin que nadie note.
  it('el baseline no tiene entradas ya resueltas', () => {
    const resueltas = []
    for (const [rel, clases] of Object.entries(baseline)) {
      const vivas = new Set(huerfanasDe(resolve(raiz, rel)))
      for (const c of clases) if (!vivas.has(c)) resueltas.push(`${rel} → ${c}`)
    }

    expect(resueltas, 'ya tienen estilo: sacalas de clasesSinEstilo.baseline.json').toEqual([])
  })
})
