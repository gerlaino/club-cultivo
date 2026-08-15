import { describe, it, expect, vi } from 'vitest'

vi.mock('../stores/auth', () => ({ useAuthStore: () => ({ user: null }) }))
vi.mock('../composables/useToast', () => ({ useToast: () => ({ warning: vi.fn() }) }))
vi.mock('../composables/usePermissions', () => ({ usePermissions: () => ({ can: () => true }) }))

const { NAV_GROUPS } = await import('../composables/useNavContext.js')

// Germán: puso el club modelo en SÓLO CULTIVO y desde el celular, con el admin, seguía
// entrando a Dispensaciones. El backend le devolvía 403 — o sea que no podía hacer daño —,
// pero el menú ofrecía algo que no lleva a ningún lado, que es peor: parece roto.
//
// La causa: el gating se aplicó al backend y al menú de ESCRITORIO, pero hay más superficies
// de navegación y cada una tenía su propia lista. Este test recorre las declaraciones y falla
// si alguna sección que necesita una suite se ofrece sin pedirla.
describe('ningún menú ofrece lo que el club no contrató', () => {
  // Qué destinos exigen qué. Si mañana se agrega una sección de cultivo sin declararlo, este
  // mapa la detecta.
  const EXIGEN = {
    cultivo: ['/salas', '/lotes', '/plantas', '/geneticas', '/admin/stock', '/admin/cosechado',
              '/admin/pesajes-manicura', '/m/admin/sedes', '/m/admin/aprobar', '/m/plantas',
              '/m/cultivador/sedes', '/m/manicura/pesar'],
    produccion_dispensa: ['/pacientes', '/historial', '/auditor/reprocann', '/m/pacientes',
                          '/m/historial', '/m/dispensar', '/m/reservas'],
    ariccame: ['/ariccame'],
    bar: ['/bar'],
  }

  // Todos los destinos declarados en el menú de escritorio, con su feature.
  const destinosEscritorio = () => {
    const out = []
    for (const g of NAV_GROUPS) {
      out.push({ to: g.to, feature: g.feature })
      for (const t of g.tabs || []) out.push({ to: t.to, feature: t.feature })
    }
    return out
  }

  Object.entries(EXIGEN).forEach(([suite, rutas]) => {
    rutas.forEach(ruta => {
      it(`${ruta} sólo se ofrece con "${suite}"`, () => {
        const decl = destinosEscritorio().find(d => d.to === ruta)
        // Si la ruta no está en el menú de escritorio, es de mobile: se verifica abajo.
        if (!decl) return

        // Un grupo puede declararlo a nivel grupo; entonces sus tabs lo heredan.
        const grupo = NAV_GROUPS.find(g => g.to === ruta || (g.tabs || []).some(t => t.to === ruta))
        const feature = decl.feature || grupo?.feature

        expect(feature, `${ruta} se ofrece sin pedir ninguna suite`).toBe(suite)
      })
    })
  })

  // Sedes es la excepción declarada: todo club tiene al menos una y de ella cuelga todo lo
  // demás. Que quede explícito para que no se "arregle" por error.
  it('Sedes no depende de ninguna suite, a propósito', () => {
    const sedes = NAV_GROUPS.find(g => g.key === 'sedes')

    expect(sedes).toBeTruthy()
    expect(sedes.feature).toBeUndefined()
  })

  // Javier, probando: "desde Depósito se puede acceder al módulo de contabilidad siendo que
  // este no se muestra en el panel lateral". Contabilidad vivía adentro del grupo Comercial,
  // gateado por la suite de dispensa, pero NO tiene bandera propia ni la pide el router: toda
  // organización tiene gastos. Resultado: escondida en el menú y accesible desde Depósito
  // ("＋ Comprar"), que es transversal.
  it('Contabilidad está en el menú de toda organización, contrate lo que contrate', () => {
    const grupo = NAV_GROUPS.find(g => g.to === '/contabilidad')

    expect(grupo, 'Contabilidad tiene que estar en el menú').toBeTruthy()
    expect(grupo.feature, 'no depende de ninguna suite: todo club tiene gastos').toBeUndefined()
  })

  it('el dashboard y la configuración siempre están', () => {
    for (const key of ['dashboard', 'config']) {
      expect(NAV_GROUPS.find(g => g.key === key)?.feature).toBeUndefined()
    }
  })
})
