// AC (Germán, 20-oct-2026): en una organización a una planta se llega por su lote o con el
// buscador, también desde el teléfono. Lo que el buscador encuentra se abre DENTRO de la app del
// teléfono (bajo /m), nunca en la pantalla de escritorio ni en el inicio.
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { rutaMovil } from '../lib/rutaMovil.js'

const fuente = (p) => readFileSync(new URL(p, import.meta.url), 'utf8')

describe('rutaMovil', () => {
  it('cada tipo de resultado del buscador tiene su ficha en el teléfono', () => {
    expect(rutaMovil('/plantas/12')).toBe('/m/planta/12')
    expect(rutaMovil('/lotes/7')).toBe('/m/lote-m/7')
    expect(rutaMovil('/salas/3')).toBe('/m/sala-m/3')
    expect(rutaMovil('/geneticas/9')).toBe('/m/geneticas/9')
    expect(rutaMovil('/pacientes/41')).toBe('/m/pacientes/41')
  })

  it('lo que no tiene versión de teléfono queda igual', () => {
    expect(rutaMovil('/analitica')).toBe('/analitica')
  })
})

describe('las rutas que el buscador necesita existen bajo /m', () => {
  const router = fuente('../router/index.js')
  // Leer el router real: si alguien borra una de estas rutas, el resultado vuelve a llevar al inicio.
  it.each(['planta/:id', 'lote-m/:id', 'sala-m/:id', 'geneticas/:id', 'pacientes/:id'])('/m/%s', (r) => {
    expect(router).toContain(`path: '${r}'`)
  })

  it('el teléfono tiene la lupa, salvo el repartidor', () => {
    const shell = fuente('../components/layout/MobileShell.vue')
    expect(shell).toMatch(/<BuscadorGlobal v-if="role !== 'delivery'" movil/)
  })
})
