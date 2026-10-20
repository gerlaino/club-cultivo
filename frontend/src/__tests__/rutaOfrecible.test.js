import { describe, it, expect, vi, beforeEach } from 'vitest'

// AC (recorrido del 20-oct-2026): «la pantalla nunca ofrece lo que el backend va a rechazar».
// El cultivador y el autocultivo veían «Sede Central» como link y caían en «No tenés acceso»; el
// dispensador veía la etiqueta del frasco 🏷️ en su stock y rebotaba al inicio.
const estado = { role: 'admin', personal: false }
vi.mock('../stores/auth', () => ({ useAuthStore: () => ({ user: { role: estado.role, club_personal: estado.personal }, isAuthenticated: true }) }))
vi.mock('../stores/club', () => ({ useClubStore: () => ({ data: { personal: estado.personal } }) }))
vi.mock('../composables/useToast', () => ({ useToast: () => ({ warning: vi.fn() }) }))
vi.mock('../composables/usePermissions', () => ({ usePermissions: () => ({ can: () => true }) }))

const { useRutaOfrecible } = await import('../composables/useRutaOfrecible.js')
const como = (role, personal = false) => { estado.role = role; estado.personal = personal; return useRutaOfrecible().ofrece }

describe('qué links puede ofrecer una pantalla', () => {
  beforeEach(() => { estado.role = 'admin'; estado.personal = false })

  it('el admin de una organización ve Sedes', () => {
    expect(como('admin')('/sedes')).toBe(true)
    expect(como('admin')('/sedes/4')).toBe(true)
  })

  it('el cultivador no: Sedes lo rebota', () => {
    expect(como('cultivador')('/sedes')).toBe(false)
    expect(como('cultivador')('/sedes/4')).toBe(false)
    expect(como('cultivador')('/salas/9')).toBe(true)
  })

  it('el autocultivo tampoco, aunque sea admin de su cuenta: no tiene sedes', () => {
    expect(como('admin', true)('/sedes')).toBe(false)
    expect(como('admin', true)('/salas/9')).toBe(true)
  })

  it('el dispensador abre la etiqueta del frasco que su stock le ofrece', () => {
    expect(como('dispensador')('/stocks/877/etiqueta')).toBe(true)
  })
})
