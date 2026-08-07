import { describe, it, expect, vi } from 'vitest'

// El router arrastra las vistas; para verificar la matriz de acceso alcanza con la decisión.
vi.mock('../stores/auth', () => ({ useAuthStore: () => ({ user: null, isAuthenticated: false }) }))
vi.mock('../composables/useToast', () => ({ useToast: () => ({ warning: vi.fn() }) }))
vi.mock('../composables/usePermissions', () => ({ usePermissions: () => ({ can: () => true }) }))

const { puedeEntrar, ROLE_HOME } = await import('../router/index.js')

// AC (Germán): "que los permisos estén bien y te bloquee entrar por ejemplo directo desde la
// URL si no tenés permisos". La matriz cubría 5 de los 11 roles: un cultivador que tipeaba
// /contabilidad o /usuarios llegaba a la pantalla, el backend le devolvía 403 y veía una
// vista rota, sin entender por qué.
describe('acceso por URL directa', () => {
  // Lo que NINGÚN rol operativo tiene que poder abrir escribiendo la dirección.
  const PROHIBIDO = {
    cultivador:  ['/contabilidad', '/usuarios', '/configuracion', '/analitica', '/pacientes',
                  '/finanzas/catalogo', '/informe-semestral', '/auditor', '/super-admin'],
    manicura:    ['/contabilidad', '/usuarios', '/pacientes', '/historial', '/analitica',
                  '/super-admin', '/bar'],
    dispensador: ['/contabilidad', '/usuarios', '/configuracion', '/salas', '/lotes',
                  '/analitica', '/super-admin', '/geneticas'],
    supervisor:  ['/contabilidad', '/usuarios', '/configuracion', '/super-admin',
                  '/finanzas/catalogo'],
    delivery:    ['/contabilidad', '/usuarios', '/pacientes', '/salas', '/super-admin'],
    medico:      ['/contabilidad', '/usuarios', '/salas', '/super-admin'],
    auditor:     ['/contabilidad', '/usuarios', '/salas', '/super-admin'],
    abogado:     ['/contabilidad', '/usuarios', '/salas', '/super-admin'],
    paciente:    ['/contabilidad', '/usuarios', '/pacientes', '/salas', '/super-admin'],
  }

  // Lo que cada uno SÍ necesita para trabajar: bloquear de más es tan malo como de menos.
  const PERMITIDO = {
    cultivador:  ['/', '/salas', '/lotes', '/plantas', '/tareas', '/geneticas', '/perfil'],
    manicura:    ['/', '/cosechado', '/lotes', '/perfil'],
    dispensador: ['/', '/pacientes', '/historial', '/admin/stock', '/bar', '/perfil'],
    supervisor:  ['/', '/salas', '/lotes', '/pacientes', '/tareas', '/perfil'],
    delivery:    ['/delivery', '/perfil'],
    medico:      ['/medico', '/perfil'],
    auditor:     ['/auditor', '/perfil'],
    abogado:     ['/abogado', '/perfil'],
    super_admin: ['/super-admin', '/perfil'],
  }

  Object.entries(PROHIBIDO).forEach(([rol, rutas]) => {
    rutas.forEach(ruta => {
      it(`${rol} NO entra a ${ruta}`, () => {
        expect(puedeEntrar(rol, ruta)).toBe(false)
      })
    })
  })

  Object.entries(PERMITIDO).forEach(([rol, rutas]) => {
    rutas.forEach(ruta => {
      it(`${rol} sí entra a ${ruta}`, () => {
        expect(puedeEntrar(rol, ruta)).toBe(true)
      })
    })
  })

  // Las rutas con parámetro son las que más se tipean a mano ("/lotes/47").
  it('las rutas con id siguen la regla de su sección', () => {
    expect(puedeEntrar('cultivador', '/lotes/47')).toBe(true)
    expect(puedeEntrar('cultivador', '/usuarios/3')).toBe(false)
    expect(puedeEntrar('dispensador', '/pacientes/12')).toBe(true)
    expect(puedeEntrar('dispensador', '/salas/5')).toBe(false)
  })

  // Un prefijo que empiece igual no puede colarse: /salas no habilita /salas-secretas.
  it('no alcanza con que la ruta empiece parecido', () => {
    expect(puedeEntrar('cultivador', '/salasdeotroclub')).toBe(false)
    expect(puedeEntrar('manicura', '/lotesprivados')).toBe(false)
  })

  // El admin no tiene matriz: su límite lo pone el permiso fino de cada ruta.
  it('el admin no queda encerrado por la matriz', () => {
    expect(puedeEntrar('admin', '/contabilidad')).toBe(true)
    expect(puedeEntrar('admin', '/usuarios')).toBe(true)
  })

  // Si se bloquea a alguien hay que mandarlo a algún lado que exista.
  it('todo rol con matriz tiene un destino al que volver', () => {
    Object.keys(PROHIBIDO).forEach(rol => {
      const destino = ROLE_HOME[rol] || '/'
      expect(puedeEntrar(rol, destino), `${rol} no puede entrar ni a su propio home`).toBe(true)
    })
  })
})
