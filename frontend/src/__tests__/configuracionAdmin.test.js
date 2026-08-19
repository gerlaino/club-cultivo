import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { NAV_GROUPS, detectGroup } from '../composables/useNavContext.js'

const AQUI = dirname(fileURLToPath(import.meta.url))
const SRC  = resolve(AQUI, '..')
const leer = (rel) => readFileSync(resolve(SRC, rel), 'utf8')

// AC: Configuración es lo que se define una vez. Todo lo que se USA seguido vive afuera, y nada
// queda sin puerta.
//
// El topbar tenía OCHO pestañas y se cortaba en pantalla. Tres no eran configuración: Suscripción
// (dos datos, con el plan calculado a ojo y los nombres de los planes viejos), Equipo (gestionar
// personas, con ruta propia desde siempre) e Integraciones (WhatsApp + webhooks, que un admin de
// club no sabe qué son).
//
// El riesgo de sacar una pestaña es dejar la pantalla sin ninguna puerta: se llega sólo escribiendo
// la URL, o no se llega. Eso ya pasó con el manicura y costó el login entero. Este test lee la
// navegación REAL —no una lista escrita de memoria, que fue el otro error de aquella vez— y exige
// que cada ruta de /configuracion tenga o una pestaña o un enlace desde otra pantalla de config.

const CONFIG = NAV_GROUPS.find(g => g.key === 'config')

/** Las rutas hijas reales de /configuracion, sin las que son sólo redirect. */
function rutasDeConfiguracion() {
  const src = leer('router/index.js')
  const desde  = src.indexOf('path: "/configuracion"')
  // Hasta el cierre del bloque: la ruta siguiente. Sin acotarlo, el slice se comía las rutas del
  // portal y el test pedía puerta para /configuracion/cuenta-corriente, que es del paciente.
  const bloque = src.slice(desde, src.indexOf("{ path: '/web',", desde))
  return [...bloque.matchAll(/\{\s*path:\s*'([a-z-]+)',\s*name:/g)].map(m => `/configuracion/${m[1]}`)
}

/** Todo `to`/`router-link` que aparezca en las pantallas de Configuración. */
function enlacesDesdeLasPantallas() {
  const dirs = ['views', 'views/admin']
  const archivos = dirs.flatMap(d =>
    readdirSync(resolve(SRC, d), { withFileTypes: true })
      .filter(e => e.isFile() && e.name.endsWith('.vue'))
      .map(e => leer(`${d}/${e.name}`)))
  return archivos.flatMap(src =>
    [...src.matchAll(/to="(\/configuracion\/[a-z-]+)"/g), ...src.matchAll(/to:\s*'(\/configuracion\/[a-z-]+)'/g)]
      .map(m => m[1]))
}

describe('Las pestañas de Configuración', () => {
  it('son sólo ajustes: nada de lo que se usa a diario', () => {
    expect(CONFIG.tabs.map(t => t.to)).toEqual([
      '/configuracion',
      '/configuracion/correo',
      '/configuracion/portal',
      '/integraciones',
      '/configuracion/papelera',
    ])
  })

  // Cada add-on se cae del menú si no está contratado. Integraciones quedó siendo la pantalla de
  // WhatsApp, así que sigue la misma regla que Correo y Portal.
  it('los add-ons se caen del menú cuando no están contratados', () => {
    const porRuta = Object.fromEntries(CONFIG.tabs.map(t => [t.to, t.feature]))

    expect(porRuta['/configuracion/correo']).toBe('mailer')
    expect(porRuta['/configuracion/portal']).toBe('vista_paciente')
    expect(porRuta['/integraciones']).toBe('whatsapp')
  })

  it('no ofrece Suscripción ni Equipo: dejaron de ser pestañas', () => {
    const etiquetas = CONFIG.tabs.map(t => t.label)

    expect(etiquetas).not.toContain('Suscripción')
    expect(etiquetas).not.toContain('Equipo')
  })
})

describe('Equipo', () => {
  it('es un grupo primario del menú lateral, no una pestaña de Configuración', () => {
    const equipo = NAV_GROUPS.find(g => g.key === 'equipo')

    expect(equipo).toBeDefined()
    expect(equipo.to).toBe('/usuarios')
  })

  // Sin esto el menú resalta Dashboard mientras estás en el equipo.
  it('estando en /usuarios el menú resalta Equipo', () => {
    expect(detectGroup('/usuarios').key).toBe('equipo')
  })
})

describe('Ninguna pantalla de Configuración queda sin puerta', () => {
  const conPestaña = new Set(CONFIG.tabs.map(t => t.to))
  const conEnlace  = new Set(enlacesDesdeLasPantallas())
  // `/configuracion` redirige a la General: la pestaña la cubre aunque la ruta se llame distinto.
  const porRedirect = new Set(
    [...leer('router/index.js').matchAll(/path:\s*'',\s*redirect:\s*'(\/configuracion\/[a-z-]+)'/g)]
      .map(m => m[1]))

  for (const ruta of rutasDeConfiguracion()) {
    it(`${ruta} se alcanza desde la navegación`, () => {
      expect(conPestaña.has(ruta) || conEnlace.has(ruta) || porRedirect.has(ruta),
        `${ruta} no tiene pestaña ni enlace: sólo se llega escribiendo la URL`).toBe(true)
    })
  }
})

describe('Alertas', () => {
  // Colgaba de la raíz (/alertas-configuracion) y su única puerta era la pestaña que se sacó.
  // Bajo /configuracion, `detectGroup` resuelve por prefijo y el menú resalta Configuración.
  it('vive bajo /configuracion, así el menú lateral no manda a Dashboard', () => {
    expect(detectGroup('/configuracion/alertas').key).toBe('config')
  })

  it('la ruta vieja sigue llevando a la nueva', () => {
    expect(leer('router/index.js')).toContain('{ path: "/alertas-configuracion", redirect: "/configuracion/alertas" }')
  })
})

describe('Los webhooks salieron de la vista del admin', () => {
  // La maquinaria queda (modelos, jobs, disparo desde Dispensacion/Paciente/Lote). Lo que se sacó
  // es la pantalla: un admin de club lee "webhook" y no sabe qué es ni de dónde sacar la URL.
  it('la pantalla de Integraciones ya no los ofrece', () => {
    const src = leer('views/IntegracionesView.vue')
    const template = src.slice(0, src.indexOf('<script'))

    expect(template.toLowerCase()).not.toContain('webhook')
  })
})
