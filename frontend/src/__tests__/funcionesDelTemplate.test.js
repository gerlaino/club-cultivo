import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const SRC = resolve(dirname(fileURLToPath(import.meta.url)), '..')

// Una función llamada en el template y no definida en el script.
//
// Vite compila el template a un render function que busca el nombre en tiempo de EJECUCIÓN, así
// que un `{{ fmtMoneda(x) }}` sin `fmtMoneda` compila perfecto y revienta cuando alguien abre la
// pantalla. Ya pasó cinco veces en este proyecto — la última, escribiendo el panel de cajas del
// tablero: el build salió limpio y la vista habría explotado en producción.
//
// `variablesInexistentes.test.js` corre ESLint `no-undef` sobre `src` y NO alcanza: esa regla no
// entra en los templates de las SFC. Ésta sí.
//
// Cubre lo llamado como función. Una PROPIEDAD suelta que no existe (`{{ foo.bar }}`) renderiza
// vacío en vez de romper, así que molesta menos y no se persigue acá.

// Lo que existe sin declararse: globals del navegador y del lenguaje.
const GLOBALES = new Set([
  'Number', 'String', 'Boolean', 'Array', 'Object', 'Math', 'Date', 'JSON', 'RegExp', 'Set', 'Map',
  'parseInt', 'parseFloat', 'isNaN', 'encodeURIComponent', 'decodeURIComponent', 'console',
  'window', 'document', 'navigator', 'localStorage', 'setTimeout', 'clearTimeout', 'alert',
  // Macros y helpers que Vue expone en el template sin que se declaren.
  '$emit', '$t', '$slots', '$attrs', '$refs', '$el', '$router', '$route',
  // Funciones de CSS: aparecen dentro de `:style="..."`, que es una expresión con CSS adentro.
  // (`gradient` sale de `linear-gradient(`, porque el guion corta el identificador.)
  'rgba', 'rgb', 'hsl', 'hsla', 'var', 'url', 'calc', 'clamp', 'repeat', 'minmax', 'gradient',
  'translate', 'translateX', 'translateY', 'scale', 'rotate', 'blur',
])

function archivos(dir) {
  return readdirSync(dir).flatMap((n) => {
    const ruta = join(dir, n)
    if (statSync(ruta).isDirectory()) return archivos(ruta)
    return n.endsWith('.vue') ? [ruta] : []
  })
}

// El template es todo lo que está fuera de <script> y <style>.
function partes(src) {
  const script = [...src.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g)].map((m) => m[1]).join('\n')
  const sinScript = src.replace(/<script[^>]*>[\s\S]*?<\/script>/g, '')
  const template = sinScript.replace(/<style[^>]*>[\s\S]*?<\/style>/g, '')
  return { script, template }
}

// Nombres llamados como función en el template.
//
// Sólo dentro de EXPRESIONES: `{{ … }}` y los atributos dinámicos (`:prop`, `@evento`, `v-if`…).
// La primera versión barría el template entero y devolvió 164 falsos positivos, todos texto
// plano: una etiqueta como «Altura (cm)» parece una llamada a `Altura(`. Un test que grita 164
// veces por nada se aprende a ignorar igual que uno que nunca grita.
//
// Se exige `nombre(` sin espacio —así se escribe una llamada— y se saltea lo que va detrás de un
// punto, porque `a.map(…)` es un método y no un identificador suelto.
function llamadasDelTemplate(template) {
  const limpio = template.replace(/<!--[\s\S]*?-->/g, '')
  const expresiones = [
    ...[...limpio.matchAll(/\{\{([\s\S]*?)\}\}/g)].map((m) => m[1]),
    ...[...limpio.matchAll(/(?::|@|v-[a-z-]+)[\w.:-]*\s*=\s*"([^"]*)"/g)].map((m) => m[1]),
    ...[...limpio.matchAll(/(?::|@|v-[a-z-]+)[\w.:-]*\s*=\s*'([^']*)'/g)].map((m) => m[1]),
  ].join('\n')

  const nombres = new Set()
  for (const [, prev, nombre] of expresiones.matchAll(/(^|[^\w.$'"`])([a-zA-Z_$][\w$]*)\(/gm)) {
    if (prev === undefined) continue
    nombres.add(nombre)
  }
  return nombres
}

describe('Toda función que el template llama existe en el script', () => {
  const vistas = archivos(SRC).filter((f) => !f.includes('__tests__'))

  it('hay componentes que revisar (si no, el test no prueba nada)', () => {
    expect(vistas.length).toBeGreaterThan(100)
  })

  it('ninguna llamada del template quedó sin definir', () => {
    const faltantes = []

    for (const f of vistas) {
      const rel = f.slice(SRC.length + 1)
      const src = readFileSync(f, 'utf8')
      const { script, template } = partes(src)
      if (!script.trim() || !template.trim()) continue

      for (const nombre of llamadasDelTemplate(template)) {
        if (GLOBALES.has(nombre)) continue
        // Declarada, importada, o recibida como prop/emit: alcanza con que el nombre aparezca
        // en el script. Es deliberadamente laxo — buscamos el olvido total, no el mal uso.
        const declarada = new RegExp(`\\b${nombre.replace('$', '\\$')}\\b`).test(script)
        if (!declarada) faltantes.push(`${rel}: el template llama a ${nombre}() y el script no lo define`)
      }
    }

    expect(faltantes).toEqual([])
  })
})
