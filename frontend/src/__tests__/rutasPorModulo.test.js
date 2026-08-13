import { describe, it, expect, vi } from 'vitest'

vi.mock('../stores/auth',   () => ({ useAuthStore: () => ({ user: null }) }))
vi.mock('../stores/club',   () => ({ useClubStore: () => ({ data: null }) }))
vi.mock('../composables/useToast',       () => ({ useToast: () => ({ warning: vi.fn() }) }))
vi.mock('../composables/usePermissions', () => ({ usePermissions: () => ({ can: () => true }) }))
vi.mock('../composables/usePWA',         () => ({ usePWA: () => ({ isPWA: false }) }))

const { moduloRequerido, MODULO_LABEL } = await import('../router/index.js')

// El menú ya esconde lo que la organización no contrató (ver menusPorSuite), pero la URL
// seguía entrando: escribir /ariccame a mano abría la pantalla y recién ahí el backend
// contestaba 403, así que se veía un cascarón vacío con un error suelto.
//
// La tabla es por PREFIJO —son 151 rutas y marcar cada una en su `meta` es acordarse en cada
// alta— así que lo que hay que verificar es que el prefijo resuelva bien: que agarre las
// rutas hijas, que gane el más largo y que NO agarre secciones transversales.
describe('qué módulo exige cada sección', () => {
  const CASOS = [
    ['/salas',                       'cultivo'],
    ['/salas/12',                    'cultivo'],
    ['/lotes/93/plantas',            'cultivo'],
    ['/geneticas',                   'cultivo'],
    ['/pacientes',                   'produccion_dispensa'],
    ['/pacientes/4',                 'produccion_dispensa'],
    ['/socios/4',                    'produccion_dispensa'],
    ['/reservas',                    'produccion_dispensa'],
    ['/historial',                   'produccion_dispensa'],
    ['/delivery/despachos',          'delivery'],
    ['/entregas',                    'delivery'],
    ['/dispositivos',                'iot'],
    ['/reglas-ambientales',          'iot'],
    ['/configuracion/correo',        'mailer'],
    ['/ariccame',                    'ariccame'],
    ['/bar',                         'bar'],
  ]

  CASOS.forEach(([ruta, modulo]) => {
    it(`${ruta} exige "${modulo}"`, () => {
      expect(moduloRequerido(ruta)).toBe(modulo)
    })
  })

  // Gana el prefijo más largo: si /bar/eventos resolviera a "bar", una organización con el
  // Buffet entraría a Eventos, que se contrata aparte.
  it('/bar/eventos pide Eventos, no sólo el Buffet', () => {
    expect(moduloRequerido('/bar/eventos')).toBe('eventos')
    expect(moduloRequerido('/bar/eventos/7')).toBe('eventos')
  })

  // Las transversales no cuelgan de ninguna suite: colgarlas ya hizo desaparecer secciones que
  // toda organización necesita. Si alguien las agrega a la tabla, esto falla.
  const TRANSVERSALES = ['/', '/perfil', '/sedes', '/tareas', '/reportes', '/configuracion',
                         '/usuarios', '/contabilidad', '/insumos']

  TRANSVERSALES.forEach(ruta => {
    it(`${ruta} no depende de ningún módulo`, () => {
      expect(moduloRequerido(ruta)).toBeNull()
    })
  })

  // Un prefijo no puede comerse a otra sección que sólo empieza igual.
  it('no bloquea por coincidencia parcial del nombre', () => {
    expect(moduloRequerido('/salas-de-espera')).toBeNull()
    expect(moduloRequerido('/barrios')).toBeNull()
  })

  it('todo módulo de la tabla tiene un nombre que se le pueda decir al usuario', () => {
    const modulos = new Set(CASOS.map(([, m]) => m).concat(['eventos']))

    modulos.forEach(m => {
      expect(MODULO_LABEL[m], `falta el nombre visible de "${m}"`).toBeTruthy()
    })
  })
})
