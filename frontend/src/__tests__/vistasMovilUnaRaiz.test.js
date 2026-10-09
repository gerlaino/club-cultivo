// LAS PANTALLAS DEL TELÉFONO TIENEN UNA SOLA RAÍZ (9-oct-2026).
//
// El armazón móvil (`MobileShell`) muestra cada pantalla dentro de `<Transition mode="out-in">`:
// la nueva se monta recién cuando terminó de irse la anterior. Si la que se va tiene más de un
// nodo raíz —un comentario arriba del <div> alcanza: en desarrollo Vue los conserva— la salida no
// termina nunca y la pantalla queda EN BLANCO. Pasaba al tocar un espacio o una planta desde «Mi
// cultivo». En el build no se ve (los comentarios se borran), por eso se escapa: este test lee
// las plantillas tal cual.
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse } from '@vue/compiler-sfc'

const SRC = resolve(dirname(fileURLToPath(import.meta.url)), '..') + '/'
const router = readFileSync(SRC + 'router/index.js', 'utf8')

// Las vistas hijas de la ruta '/m' (el bloque `children: [ … ]` que sigue a `path: '/m'`).
function vistasDelArmazon () {
  const ini = router.indexOf("path: '/m',")
  const abre = router.indexOf('children: [', ini) + 'children: '.length
  let nivel = 0, fin = abre
  for (; fin < router.length; fin++) {
    if (router[fin] === '[') nivel++
    else if (router[fin] === ']' && --nivel === 0) break
  }
  const bloque = router.slice(abre, fin)
  return [...new Set([...bloque.matchAll(/import\('\.\.\/(views\/[^']+\.vue)'\)/g)].map(m => m[1]))]
}

// Nodos de primer nivel de la plantilla, sin el texto en blanco. 1 = elemento, 3 = comentario.
// Una cadena v-if / v-else-if / v-else cuenta como UNA raíz: renderiza un solo elemento.
const directiva = (n, nombre) => (n.props || []).some(pr => pr.type === 7 && pr.name === nombre)
function raices (ruta) {
  const { descriptor } = parse(readFileSync(SRC + ruta, 'utf8'), { filename: ruta })
  const nodos = (descriptor.template?.ast?.children || []).filter(n => !(n.type === 2 && !n.content.trim()))
  return nodos.filter(n => !(n.type === 1 && (directiva(n, 'else') || directiva(n, 'else-if'))))
}

describe('pantallas del teléfono', () => {
  const vistas = vistasDelArmazon()

  it('encuentra las vistas del armazón móvil', () => {
    // Si el router cambia de forma y esto encuentra pocas, el test pasaría sin mirar nada.
    expect(vistas.length).toBeGreaterThan(20)
    expect(vistas).toContain('views/mobile/MPersonalCultivoView.vue')
  })

  for (const ruta of vistasDelArmazon()) {
    it(`${ruta} tiene un solo elemento raíz`, () => {
      const nodos = raices(ruta)
      const desc = nodos.map(n => (n.type === 1 ? `<${n.tag}>` : n.type === 3 ? '<!-- comentario -->' : 'texto'))
      expect(desc, 'el comentario va ADENTRO del elemento raíz').toHaveLength(1)
      expect(nodos[0].type).toBe(1)
    })
  }
})
