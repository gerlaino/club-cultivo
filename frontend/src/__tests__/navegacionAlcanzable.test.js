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

  // Las pantallas que se abren escaneando una etiqueta (o tocando la planta en la ficha del
  // lote). No están en ningún menú —se llega por la cámara o desde la ficha de al lado— así que
  // no hay forma de "no ofrecerlas": si el rol no puede abrirlas, el botón rebota.
  //
  // El caso real: el manicura tocaba una planta para registrar su peso y le decía que no tenía
  // permisos, porque el detalle del lote lo manda a /p/<codigo_qr>.
  describe('las pantallas de etiqueta (QR)', () => {
    const OPERATIVOS = ['cultivador', 'supervisor', 'manicura', 'dispensador']
    const ETIQUETAS  = { planta: '/p/ABC123', stock: '/s/XYZ789', lote: '/l/L-26-001' }

    for (const rol of OPERATIVOS) {
      for (const [que, ruta] of Object.entries(ETIQUETAS)) {
        it(`${rol} puede abrir la etiqueta de ${que}`, () => {
          expect(puedeEntrar(rol, ruta)).toBe(true)
        })
      }
    }

    // El prefijo corto no puede abrir de más: '/p' no es '/pacientes' ni '/perfil'.
    it('el prefijo de etiqueta no le abre otras secciones al manicura', () => {
      expect(puedeEntrar('manicura', '/pacientes')).toBe(false)
      expect(puedeEntrar('manicura', '/salas')).toBe(false)
    })
  })

  // Los dos candados del frontend tienen que decir lo mismo. Una ruta cuyo `beforeEnter` deja
  // pasar a un rol, y una matriz que lo rebota antes de llegar, es una contradicción: gana la
  // matriz (corre primero, global) y el permiso escrito en la ruta no existe en la práctica.
  //
  // Así aparecieron /mnc (manicura), /stock y /reservas (dispensador) y /admin/pesajes-manicura
  // (supervisor): la ruta decía que sí y la matriz decía que no.
  describe('la matriz y los permisos de cada ruta no se contradicen', () => {
    const src = leer('router/index.js')

    /** Rutas con lista EXPLÍCITA de quiénes pueden (`if (!['a','b'].includes(role)) …`). */
    function rutasConAllowList() {
      const re = /path:\s*'([^']+)'([\s\S]*?)(?=\n\s{2,4}\{\n\s*(?:\/\/[^\n]*\n\s*)*path:|\nconst |\n\];)/g
      const out = []
      for (const m of src.matchAll(re)) {
        const [, path, chunk] = m
        for (const g of chunk.matchAll(/if\s*\(\s*!\s*\[([^\]]*)\]\.includes\(\s*(?:auth\.user\?\.role|role)\s*\)/g)) {
          out.push({ path, roles: [...g[1].matchAll(/'([a-z_]+)'/g)].map(x => x[1]) })
        }
      }
      return out
    }

    it('encuentra rutas con lista de roles (si no, el test no está mirando nada)', () => {
      expect(rutasConAllowList().length).toBeGreaterThan(5)
    })

    it('ningún rol tiene permiso en la ruta y prohibición en la matriz', () => {
      // Excepciones conscientes, con su razón:
      const ESPERADAS = [
        // El super admin vive en /super-admin y no entra a las pantallas de una organización
        // (ver `block_super_admin_sin_contexto!`): que la papelera lo nombre es un resto viejo.
        'super_admin → /admin/papelera',
        // Sale del hijo `despachos`, que nombra a supervisor; el path que se ve acá es el del
        // padre. El padre /delivery sólo deja pasar admin y delivery, así que el supervisor no
        // llega a despachos aunque el hijo lo nombre — y el repartidor tampoco, porque el hijo
        // no lo nombra a él: en los hechos despachos es de admin. Es una decisión comercial
        // pendiente (Delivery es add-on pago), no un olvido de la matriz: para resolverla hay
        // que tocar el padre Y la matriz, no sólo esta lista.
        'supervisor → /delivery',
      ]

      const choques = []
      for (const { path, roles } of rutasConAllowList()) {
        for (const rol of roles) {
          const concreta = path.replace(/:[a-zA-Z_]+/g, '1')
          if (!puedeEntrar(rol, concreta)) choques.push(`${rol} → ${concreta}`)
        }
      }

      expect(choques.filter(c => !ESPERADAS.includes(c))).toEqual([])
    })
  })

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
