import { describe, it, expect, vi } from 'vitest'

// El router arrastra las vistas; para verificar la matriz de acceso alcanza con la decisión.
vi.mock('../stores/auth', () => ({ useAuthStore: () => ({ user: null, isAuthenticated: false }) }))
vi.mock('../composables/useToast', () => ({ useToast: () => ({ warning: vi.fn() }) }))
vi.mock('../composables/usePermissions', () => ({ usePermissions: () => ({ can: () => true }) }))

const { puedeEntrar, ROLE_HOME, MOBILE_ROLES, MOBILE_HOME } = await import('../router/index.js')

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

  // El bug que hacía que el delivery no pudiera entrar desde la PWA instalada: el guard de
  // PWA lo empujaba a su MOBILE_HOME (bajo /m), la matriz no admitía /m y lo rebotaba, y el
  // guard lo volvía a empujar. Loop infinito, que desde afuera se ve como "queda cargando".
  describe('los roles que usan la PWA', () => {
    MOBILE_ROLES.forEach(rol => {
      it(`${rol} puede entrar a su pantalla de la PWA (${MOBILE_HOME[rol]})`, () => {
        expect(puedeEntrar(rol, MOBILE_HOME[rol])).toBe(true)
      })

      it(`${rol} puede navegar por el resto de /m`, () => {
        expect(puedeEntrar(rol, '/m/horas')).toBe(true)
      })
    })

    it('un rol que NO usa la PWA no necesita /m', () => {
      expect(MOBILE_ROLES).not.toContain('medico')
      expect(MOBILE_ROLES).not.toContain('auditor')
    })
  })
})

// El bloque de arriba es una lista de PROHIBIDOS: atrapa "entra donde no debería", nunca lo
// contrario. Por eso se coló que el dispensador tuviera `tareas: ['index','show']` en la matriz
// de permisos y `/tareas` NO estuviera en sus prefijos de ruta: el permiso decía que sí, el
// router lo rebotaba, y ningún test comparaba las dos listas.
//
// Es la forma más cara del bug en este proyecto —"la pantalla te deja y el router te rechaza"—
// porque parece culpa del usuario. Este bloque cruza las dos fuentes.
describe('lo que la matriz de permisos concede, el router lo deja abrir', () => {
  // Sólo los recursos que tienen UNA dirección, la misma para todos los roles.
  //
  // La primera versión mapeaba también socios, dispensaciones, lotes, plantas y sedes, y devolvía
  // 11 "divergencias" que no lo eran: el médico llega a sus pacientes por /medico/pacientes y el
  // auditor por /auditor/…, así que el permiso `socios` con /pacientes cerrado es correcto. Un
  // test que falla por el motivo equivocado hace tanto daño como uno que pasa por el equivocado:
  // se aprende a ignorarlo.
  //
  // Si mañana otro recurso pasa a tener una única pantalla compartida, va acá.
  const RUTA_DEL_RECURSO = {
    tareas: '/tareas',
  }

  // Divergencias conocidas y todavía SIN decidir. No se arreglan de prepo porque no está claro
  // cuál de las dos listas tiene razón:
  //
  //   medico/tareas — la matriz le da `tareas: ['index','show']` y el router le cierra /tareas.
  //     O el permiso quedó viejo (las tareas son de cultivo y el médico trabaja con turnos), o
  //     falta el prefijo. Lo decide Germán; mientras tanto queda acá para que se vea.
  const PENDIENTES_DE_DECIDIR = ["medico: puede 'tareas' pero el router le cierra /tareas"]

  it('cada recurso con index tiene una ruta que ese rol puede abrir', async () => {
    // El archivo mockea usePermissions para poder importar el router sin arrastrar la sesión;
    // la matriz hay que traerla del módulo REAL, o el test se compara contra el mock.
    const { PERMISSIONS } = await vi.importActual('../composables/usePermissions.js')
    const faltantes = []

    for (const [rol, recursos] of Object.entries(PERMISSIONS ?? {})) {
      if (rol === 'admin' || rol === 'super_admin') continue
      for (const [recurso, acciones] of Object.entries(recursos)) {
        const ruta = RUTA_DEL_RECURSO[recurso]
        if (!ruta || !acciones.includes('index')) continue
        if (!puedeEntrar(rol, ruta)) faltantes.push(`${rol}: puede '${recurso}' pero el router le cierra ${ruta}`)
      }
    }

    expect(faltantes).toEqual(PENDIENTES_DE_DECIDIR)
  })
})
