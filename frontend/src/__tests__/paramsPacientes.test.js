import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

// AC: buscar un paciente filtra la lista.
//
// El bug real: el buscador de la dispensa mandaba `q` y el backend lee `query`. Rails ignora un
// parámetro que no conoce, así que el filtro se descartaba EN SILENCIO y volvía la primera página
// entera. Desde la pantalla se ve como "la búsqueda no anda", pero no hay ningún error: ni el
// build, ni el linter, ni un test de componente que mockee la API lo detectan, porque el frontend
// hace exactamente lo que dice hacer y el backend también.
//
// El mismo error estaba en Contabilidad con `per_page` en vez de `limite`: pedía 500 pacientes y
// recibía 20. No se notó hasta que una organización tuvo más de 20.
//
// Por eso el test mira los NOMBRES DE PARÁMETRO contra los que el controller lee de verdad, que
// es donde viven los dos bugs. `GET /pacientes` es el endpoint más consumido de la app.
const SRC = resolve(dirname(fileURLToPath(import.meta.url)), '..')

// Los que lee `PacientesController#index`. Si agregás uno en el backend, sumalo acá.
const CONOCIDOS = ['pagina', 'limite', 'query', 'dni', 'orden', 'dir', 'sin_seguimiento']

// Nombres que parecen razonables y NO existen: es lo que uno escribe de memoria viniendo de otra
// API. Cada uno mapea al que sí funciona, para que el mensaje del error diga qué poner.
const EQUIVOCADOS = {
  q: 'query', search: 'query', busqueda: 'query', term: 'query',
  per_page: 'limite', limit: 'limite', page: 'pagina', order: 'orden',
}

function archivos(dir) {
  return readdirSync(dir).flatMap((n) => {
    const ruta = join(dir, n)
    if (statSync(ruta).isDirectory()) return archivos(ruta)
    return /\.(vue|js)$/.test(n) ? [ruta] : []
  })
}

describe('Los parámetros de GET /pacientes', () => {
  const consumidores = archivos(SRC)
    .filter((f) => !f.includes('__tests__') && !f.endsWith('lib/api.js'))
    .map((f) => ({ f: f.slice(SRC.length + 1), src: readFileSync(f, 'utf8') }))
    .filter(({ src }) => src.includes('listPacientes'))

  it('hay pantallas que consumen el endpoint (si no, el test no prueba nada)', () => {
    expect(consumidores.length).toBeGreaterThan(3)
  })

  it.each(Object.entries(EQUIVOCADOS))(
    'ninguna manda "%s" (el backend lee "%s")',
    (malo, bueno) => {
      for (const { f, src } of consumidores) {
        // Sólo en posición de clave de objeto: `q:` o `.q =`. Así no se dispara con una variable
        // que se llame `search` ni con la palabra suelta en un comentario.
        const comoClave = new RegExp(`(\\{|,|\\.)\\s*${malo}\\s*(:|=[^=])`)

        expect(comoClave.test(src), `${f}: manda "${malo}" a listPacientes; el backend lee "${bueno}"`)
          .toBe(false)
      }
    },
  )

  it('todo lo que mandan son parámetros que el backend lee', () => {
    for (const { f, src } of consumidores) {
      // Las claves de los objetos literales que se le pasan a listPacientes en la misma línea.
      for (const [, cuerpo] of src.matchAll(/listPacientes\(\s*\{([^}]*)\}/g)) {
        for (const [, clave] of cuerpo.matchAll(/(?:^|,)\s*([a-z_]+)\s*:/gi)) {
          expect(CONOCIDOS, `${f}: manda "${clave}", que PacientesController#index no lee`)
            .toContain(clave)
        }
      }
    }
  })
})
