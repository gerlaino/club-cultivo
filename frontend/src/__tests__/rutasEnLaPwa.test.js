import { describe, it, expect, vi } from 'vitest'

// El router arrastra las vistas; para verificar la decisión alcanza con la función.
vi.mock('../stores/auth', () => ({ useAuthStore: () => ({ user: null, isAuthenticated: false }) }))
vi.mock('../composables/useToast', () => ({ useToast: () => ({ warning: vi.fn() }) }))
vi.mock('../composables/usePermissions', () => ({ usePermissions: () => ({ can: () => true }) }))
vi.mock('../composables/usePWA', () => ({ usePWA: () => ({ isPWA: () => true }) }))

const { rutaEnShell } = await import('../router/index.js')

// UN LINK DE ESCRITORIO, ABIERTO DESDE LA PWA INSTALADA.
//
// El guard rebota todo lo que no empiece con `/m` para no sacar a la persona del shell. Pero
// varias pantallas se montan en los dos lados sin escribirse dos veces —`/m/mostrador`,
// `/m/stock`, `/m/historial`— así que rebotar al home era perder un viaje que tenía destino.
//
// Le pegó a lo que más se usa: "Ir al mostrador", el link de la tarjeta de caja que el
// dispensador tiene arriba de su buscador de pacientes, lo devolvía a esa misma pantalla. Un
// botón que no hace nada es peor que un botón que avisa por qué no puede.
describe('un link de escritorio dentro de la PWA', () => {
  const CON_EQUIVALENTE = [
    ['/mostrador',  '/m/mostrador'],
    ['/stock',      '/m/stock'],
    ['/historial',  '/m/historial'],
    ['/reservas',   '/m/reservas'],
    ['/pacientes',  '/m/pacientes'],
    ['/tareas',     '/m/tareas'],
  ]

  CON_EQUIVALENTE.forEach(([escritorio, mobile]) => {
    it(`${escritorio} entra al shell por ${mobile}`, () => {
      expect(rutaEnShell({ path: escritorio }, 'dispensador')).toBe(mobile)
    })
  })

  // El admin con varias sedes llega al mostrador de UNA sede con `?sede=`. Si el salto al shell
  // se comiera la query, aterrizaría en la primera de la lista, que puede no ser la que fue a ver.
  it('se lleva la query: sin eso, aterriza en otra sede', () => {
    expect(rutaEnShell({ path: '/mostrador', query: { sede: '10' } }, 'admin'))
      .toBe('/m/mostrador?sede=10')
  })

  // Lo que NO tiene pantalla mobile sigue yendo al home del rol, como antes.
  it('lo que no existe bajo /m no inventa una ruta', () => {
    expect(rutaEnShell({ path: '/contabilidad' }, 'admin')).toBe(null)
    expect(rutaEnShell({ path: '/no-existe-esta-pantalla' }, 'admin')).toBe(null)
  })

  // `/m/` es el redirect al home del rol: es lo mismo que ya hace el guard, y pasar por acá sólo
  // agrega un salto.
  it('la raíz no se toca', () => {
    expect(rutaEnShell({ path: '/' }, 'dispensador')).toBe(null)
  })
})

// BAJO `/m` LA MATRIZ ES UN SOLO PREFIJO PARA TODO EL SHELL: cualquier rol mobile entra a
// cualquier `/m/...`. El permiso fino vive en la ruta de ESCRITORIO, así que es ahí donde hay
// que preguntar — si no, tocar un link a `/pacientes` le abriría el padrón a un repartidor sólo
// por pasar por el shell. La PWA no puede ser más permisiva que el escritorio.
describe('el salto al shell no puede ampliar permisos', () => {
  const PROHIBIDO = [
    ['delivery',   '/pacientes'],
    ['delivery',   '/historial'],
    ['manicura',   '/pacientes'],
    ['manicura',   '/historial'],
    ['cultivador', '/mostrador'],
    ['cultivador', '/pacientes'],
  ]

  PROHIBIDO.forEach(([rol, ruta]) => {
    it(`${rol} no llega a ${ruta} por el shell`, () => {
      expect(rutaEnShell({ path: ruta }, rol)).toBe(null)
    })
  })

  it('y el que sí puede, entra', () => {
    expect(rutaEnShell({ path: '/mostrador' }, 'supervisor')).toBe('/m/mostrador')
    expect(rutaEnShell({ path: '/tareas' }, 'cultivador')).toBe('/m/tareas')
  })
})
