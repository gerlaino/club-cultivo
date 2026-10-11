import { describe, it, expect, vi, beforeEach } from 'vitest'

// AC (11-oct-2026, Germán): «cada vez que entro a la app se ve una vista vieja y después la actual».
// Lo personal se sabía recién con las preferencias del club, que cargan en segundo plano; mientras
// tanto todo se dibujaba como una organización. Ahora, hasta que lleguen, vale lo que dijo /me
// (que el router espera antes de mostrar nada).
const club = { data: null }
const auth = { user: null }
vi.mock('../stores/club', () => ({ useClubStore: () => club }))
vi.mock('../stores/auth', () => ({ useAuthStore: () => auth }))

const { esUsoPersonal, useUsoPersonal } = await import('../composables/useUsoPersonal.js')

describe('¿uso personal? desde el primer cuadro', () => {
  beforeEach(() => { club.data = null; auth.user = null })

  it('sin preferencias todavía, vale lo que dijo /me', () => {
    auth.user = { role: 'admin', club_personal: true }
    expect(esUsoPersonal()).toBe(true)
    expect(useUsoPersonal().esPersonal.value).toBe(true)
  })

  it('una organización sigue siendo organización', () => {
    auth.user = { role: 'admin', club_personal: false }
    expect(esUsoPersonal()).toBe(false)
  })

  it('cuando llegan las preferencias, mandan ellas', () => {
    auth.user = { role: 'admin', club_personal: true }
    club.data = { personal: false }
    expect(esUsoPersonal()).toBe(false)
  })

  it('sin /me ni preferencias, no inventa', () => {
    expect(esUsoPersonal()).toBe(false)
  })
})
