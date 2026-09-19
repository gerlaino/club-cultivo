// Uso personal (sep-2026): el cultivador de casa entra a la misma app con otro envoltorio. Lo
// que estas pruebas fijan es que la REGLA de qué se le esconde vive en un solo lugar y que las
// dos superficies (menú de escritorio, rutas) la leen de ahí.
import { describe, it, expect } from 'vitest'
import { NAV_GROUPS, entradaVisible } from '../composables/useNavContext.js'
import { soloDeOrganizacion } from '../router/index.js'

const personal = { personal: true, features: { cultivo: true, iot: true } }
const org      = { personal: false, features: { cultivo: true, produccion_dispensa: true } }

describe('el menú del uso personal', () => {
  const visibles = (club) => NAV_GROUPS.filter(g => entradaVisible(g, club)).map(g => g.key)

  it('no ofrece Sedes ni Equipo: la sede es su casa y la cuenta es la persona', () => {
    expect(visibles(personal)).not.toContain('sedes')
    expect(visibles(personal)).not.toContain('equipo')
  })

  it('sí ofrece lo suyo: cultivo, producción, gastos, tareas y reportes', () => {
    for (const k of ['dashboard', 'cultivo', 'produccion', 'contabilidad', 'tareas', 'reportes', 'config']) {
      expect(visibles(personal), k).toContain(k)
    }
  })

  it('tampoco lo de la dispensa, que no tiene contratada', () => {
    for (const k of ['pacientes', 'mostrador', 'comercial', 'salon']) expect(visibles(personal)).not.toContain(k)
  })

  it('a una organización no le cambia nada', () => {
    expect(visibles(org)).toContain('sedes')
    expect(visibles(org)).toContain('equipo')
  })
})

describe('las rutas que en uso personal no existen', () => {
  it('son Sedes y Equipo, con sus hijas', () => {
    expect(soloDeOrganizacion('/sedes')).toBe(true)
    expect(soloDeOrganizacion('/sedes/3')).toBe(true)
    expect(soloDeOrganizacion('/usuarios')).toBe(true)
    expect(soloDeOrganizacion('/usuarios/12')).toBe(true)
  })

  it('y nada más: /salas, /lotes o /contabilidad siguen siendo suyas', () => {
    for (const p of ['/salas', '/lotes', '/contabilidad', '/auditor', '/m/personal/hoy']) {
      expect(soloDeOrganizacion(p), p).toBe(false)
    }
  })
})
