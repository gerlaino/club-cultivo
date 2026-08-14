import { describe, it, expect, vi } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

vi.mock('../stores/auth', () => ({ useAuthStore: () => ({ user: null, isAuthenticated: false }) }))
vi.mock('../composables/useToast', () => ({ useToast: () => ({ warning: vi.fn() }) }))
vi.mock('../composables/usePermissions', () => ({ usePermissions: () => ({ can: () => true }) }))

const { puedeEntrar } = await import('../router/index.js')

const AQUI = dirname(fileURLToPath(import.meta.url))
const leer = (rel) => readFileSync(resolve(AQUI, '..', rel), 'utf8')

// AC: un rol tiene que poder ABRIR lo que su propia navegación le muestra. Un botón que rebota
// es peor que un botón que no está: la persona no entiende si se rompió la app o si hizo algo mal.
//
// El caso que lo destapó: el manicura no podía iniciar sesión. Al entrar, "/" lo manda a
// /mnc/pendientes, pero /mnc no estaba en su matriz de prefijos → el guard lo devolvía a "/" →
// que lo volvía a mandar a /mnc. El login autenticaba bien (200 en el backend) y la app se
// quedaba en el formulario, sin ningún error. Igual de rotos estaban "Mis horas" del cultivador,
// "Stock" y "Reservas" del dispensador y "Analítica" del supervisor.
//
// La matriz se había escrito de memoria, y el test que la cubría repetía la misma lista de
// memoria: por eso pasaba en verde. Este la contrasta contra la navegación REAL.
describe('cada rol puede abrir lo que su navegación le ofrece', () => {
  // De dónde sale el menú de cada rol (los que tienen matriz de prefijos).
  const SIDEBAR_POR_ROL = {
    manicura:    'components/layout/ManicuraSidebar.vue',
    cultivador:  'components/layout/CultivadorSidebar.vue',
    dispensador: 'components/layout/DispensadorSidebar.vue',
    supervisor:  'components/layout/SupervisorSidebar.vue',
  }

  /** Los destinos fijos del componente: `to: '/loquesea'` y `to="/loquesea"`. */
  function destinosDe(archivo) {
    const src = leer(archivo)
    const rutas = [...src.matchAll(/to:\s*'(\/[^']*)'/g), ...src.matchAll(/to="(\/[^"]*)"/g)]
      .map(m => m[1])
      // Las que llevan parámetro se resuelven en runtime: no hay una URL fija que verificar.
      .filter(r => !r.includes(':') && !r.includes('${'))
    return [...new Set(rutas)]
  }

  for (const [rol, archivo] of Object.entries(SIDEBAR_POR_ROL)) {
    it(`${rol}: ningún link de su barra lo rebota`, () => {
      const destinos = destinosDe(archivo)
      expect(destinos.length, `no se encontró ningún link en ${archivo}`).toBeGreaterThan(0)

      const rebotados = destinos.filter(r => !puedeEntrar(rol, r))
      expect(rebotados, `${rol} ve estos links pero no puede abrirlos`).toEqual([])
    })
  }

  // Lo más caro de todo: si el rol no puede entrar a donde aterriza, no entra a NINGÚN lado.
  // El guard lo devuelve al origen, que lo vuelve a mandar al mismo lugar.
  describe('el aterrizaje del login', () => {
    // Salida del `beforeEnter` de "/" (router/index.js). Es la primera pantalla tras entrar.
    const ATERRIZAJE = {
      manicura:    '/mnc/pendientes',
      auditor:     '/auditor',
      medico:      '/medico',
      abogado:     '/abogado',
      delivery:    '/delivery',
      super_admin: '/super-admin',
      // Los que se quedan en el dashboard.
      cultivador:  '/',
      supervisor:  '/',
      dispensador: '/',
      paciente:    '/',
    }

    for (const [rol, destino] of Object.entries(ATERRIZAJE)) {
      it(`${rol} puede entrar a ${destino}`, () => {
        expect(puedeEntrar(rol, destino)).toBe(true)
      })
    }

    // La regla, escrita como tal: aterrizar en un lugar prohibido es un ida y vuelta infinito
    // contra el guard, y desde afuera se ve como "no puedo iniciar sesión".
    it('ningún rol aterriza en una sección que tiene prohibida', () => {
      const rotos = Object.entries(ATERRIZAJE)
        .filter(([rol, destino]) => !puedeEntrar(rol, destino))
        .map(([rol, destino]) => `${rol} → ${destino}`)

      expect(rotos).toEqual([])
    })
  })
})
