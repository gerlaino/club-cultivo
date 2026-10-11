import { describe, it, expect, vi, beforeEach } from 'vitest'

// AC (11-oct-2026, Germán): lo de autocultivo tiene que estar hecho para ese uso, sin tocar lo de
// organizaciones. En autocultivo el lote no se nombra: el próximo paso dice que el número se lo
// pusiste vos a tus plantas, no «el plan del lote». Una organización lo sigue leyendo igual.
const club = { data: null }
vi.mock('../stores/club', () => ({ useClubStore: () => club }))
vi.mock('../stores/auth', () => ({ useAuthStore: () => ({ user: null }) }))

const { textoProximoPaso } = await import('../lib/loteHelpers.js')
const paso = { proximo_paso: { fase: 'floracion', faltan_dias: -13, objetivo_dias: 30, objetivo_origen: 'lote', lleva_dias: 43 } }

describe('Próximo paso en autocultivo', () => {
  beforeEach(() => { club.data = null })

  it('no habla del lote', () => {
    club.data = { personal: true }
    const t = textoProximoPaso(paso)
    expect(t).toContain('les pusiste 30 de vege; lleva 43')
    expect(t).not.toMatch(/lote/i)
  })

  it('en una organización sigue diciendo «el plan del lote»', () => {
    club.data = { personal: false }
    expect(textoProximoPaso(paso)).toContain('el plan del lote pide 30 de vege')
  })
})
