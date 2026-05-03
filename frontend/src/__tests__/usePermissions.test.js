import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from '../stores/auth.js'
import { usePermissions } from '../composables/usePermissions.js'

function withRole(role) {
  const auth = useAuthStore()
  auth.user = { role, first_name: 'Test' }
  return usePermissions()
}

beforeEach(() => {
  setActivePinia(createPinia())
})

describe('usePermissions — admin', () => {
  it('can do anything', () => {
    const { can } = withRole('admin')
    expect(can('socios', 'destroy')).toBe(true)
    expect(can('plantas', 'create')).toBe(true)
    expect(can('anything', 'any')).toBe(true)
  })
})

describe('usePermissions — medico', () => {
  it('can read socios', () => {
    const { can } = withRole('medico')
    expect(can('socios', 'index')).toBe(true)
    expect(can('socios', 'show')).toBe(true)
  })

  it('cannot access lotes or salas', () => {
    const { can } = withRole('medico')
    expect(can('lotes', 'index')).toBe(false)
    expect(can('salas', 'index')).toBe(false)
  })
})

describe('usePermissions — cultivador', () => {
  it('can manage plantas and lotes', () => {
    const { can } = withRole('cultivador')
    expect(can('plantas', 'create')).toBe(true)
    expect(can('lotes', 'destroy')).toBe(true)
    expect(can('salas', 'show')).toBe(true)
  })

  it('cannot access dispensaciones or socios create', () => {
    const { can } = withRole('cultivador')
    expect(can('dispensaciones', 'create')).toBe(false)
    expect(can('socios', 'create')).toBe(false)
  })
})

describe('usePermissions — dispensador', () => {
  it('can create dispensaciones', () => {
    const { can } = withRole('dispensador')
    expect(can('dispensaciones', 'create')).toBe(true)
    expect(can('socios', 'index')).toBe(true)
  })

  it('cannot manage plantas or lotes', () => {
    const { can } = withRole('dispensador')
    expect(can('plantas', 'create')).toBe(false)
    expect(can('lotes', 'create')).toBe(false)
  })
})

describe('usePermissions — manicura', () => {
  it('can access manicura', () => {
    const { can } = withRole('manicura')
    expect(can('manicura', 'access')).toBe(true)
    expect(can('sede_inventario', 'show')).toBe(true)
  })

  it('cannot access socios or dispensaciones', () => {
    const { can } = withRole('manicura')
    expect(can('socios', 'index')).toBe(false)
    expect(can('dispensaciones', 'create')).toBe(false)
  })
})

describe('usePermissions — socio', () => {
  it('can only access mi_perfil and mis_dispensaciones', () => {
    const { can } = withRole('socio')
    expect(can('mi_perfil', 'show')).toBe(true)
    expect(can('mis_dispensaciones', 'index')).toBe(true)
    expect(can('socios', 'index')).toBe(false)
    expect(can('plantas', 'index')).toBe(false)
  })
})

describe('usePermissions — no role', () => {
  it('returns false for all checks', () => {
    const auth = useAuthStore()
    auth.user = null
    const { can } = usePermissions()
    expect(can('socios', 'index')).toBe(false)
    expect(can('plantas', 'create')).toBe(false)
  })
})

describe('usePermissions — role helpers', () => {
  it('isAdmin is true for admin', () => {
    const { isAdmin } = withRole('admin')
    expect(isAdmin.value).toBe(true)
  })

  it('isCultivador is true for cultivador', () => {
    const { isCultivador } = withRole('cultivador')
    expect(isCultivador.value).toBe(true)
  })

  it('isMedico is true for medico', () => {
    const { isMedico } = withRole('medico')
    expect(isMedico.value).toBe(true)
  })
})
