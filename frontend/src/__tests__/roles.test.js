import { describe, it, expect } from 'vitest'
import { ROLES, rolInfo, rolPermisos, rolPideSede, rolHintSede } from '../lib/roles.js'

// AC: la explicación de qué hace cada rol no puede depender de la pantalla desde la que se
// mire. Estaba duplicada en UsuariosView y UsuarioDetail, con textos distintos para el mismo
// rol ("Acceso total al club" vs "Acceso total al sistema").
describe('metadata de roles', () => {
  // Los 9 roles operativos del club. `super_admin` no es del club y `paciente` todavía no
  // tiene login (ver tarea del portal del paciente).
  const ESPERADOS = ['admin', 'medico', 'cultivador', 'supervisor', 'manicura',
                     'dispensador', 'delivery', 'abogado', 'auditor']

  it('están los roles que el admin puede asignar', () => {
    expect(ROLES.map(r => r.value)).toEqual(ESPERADOS)
  })

  it('cada rol se explica y dice qué puede y qué no', () => {
    for (const r of ROLES) {
      expect(r.desc, `${r.value} sin descripción`).toBeTruthy()
      expect(r.permisos.length, `${r.value} sin permisos`).toBeGreaterThan(0)
      expect(r.permisos.some(p => p.ok), `${r.value} no puede hacer nada`).toBe(true)
    }
  })

  // El admin puede todo: una lista con un "no" ahí sería mentira.
  it('el admin no tiene permisos negados', () => {
    expect(rolPermisos('admin').every(p => p.ok)).toBe(true)
  })

  // Ningún rol EXIGE sede: sin asignar, todos ven lo de todo el club. Es lo que necesita un
  // club de una sola sede, que si no tendría que asignársela a cada persona para que la app
  // le sirva. Lo que sí hace falta es que cada uno lo explique (ver el test de abajo).
  it('ningún rol queda inutilizable por no tener sede asignada', () => {
    expect(rolPideSede('cultivador')).toBe(false)
    expect(rolPideSede('supervisor')).toBe(false)
    expect(rolPideSede('dispensador')).toBe(false)
    expect(rolPideSede('admin')).toBe(false)
  })

  it('los roles que se acotan por sede explican qué pasa si no se les asigna ninguna', () => {
    for (const r of ROLES.filter(x => x.sedes)) {
      expect(rolHintSede(r.value), `${r.value} sin hint de sede`).toBeTruthy()
    }
  })

  it('un rol desconocido no rompe la vista', () => {
    const info = rolInfo('inventado')

    expect(info.label).toBe('inventado')
    expect(info.permisos).toEqual([])
  })
})
