import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount } from '@vue/test-utils'

// EL PORTAL EN EL TELÉFONO (28-oct-2026, Germán: «las indicaciones para que instale la PWA para
// poder entrar al portal es fundamental»).
//
// AC:
//   - En el teléfono, si todavía no lo instaló, el inicio le ofrece tenerlo como app.
//   - En Android con el aviso del navegador: un botón que lo instala. En iPhone: los pasos de
//     Safari (Compartir → Agregar a inicio). En otro Android: los pasos del menú.
//   - Ya instalado (abierto como app) o en la compu, no aparece.
//   - «Ahora no» lo esconde (vuelve a las dos semanas).
//   - La puerta de su organización queda recordada en el teléfono: si la sesión vence, vuelve a la suya.

const pwa = vi.hoisted(() => ({ instalada: false }))
vi.mock('@/composables/usePWA', () => ({ usePWA: () => ({ isPWA: () => pwa.instalada }) }))

const UA_ORIGINAL = navigator.userAgent
function conUA(ua) { Object.defineProperty(navigator, 'userAgent', { value: ua, configurable: true }) }
const ANDROID = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36'
const IPHONE  = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'
const COMPU   = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/130 Safari/537.36'

async function montar() {
  vi.resetModules()
  const lib = await import('@/lib/puertaPortal')
  const { default: C } = await import('../components/portal/PortalInstalar.vue')
  return { w: mount(C, { props: { nombre: 'Club Modelo' } }), lib }
}

beforeEach(() => { localStorage.clear(); pwa.instalada = false })
afterEach(() => conUA(UA_ORIGINAL))

describe('Tener el portal en el teléfono', () => {
  it('en Android con el aviso del navegador, un botón lo instala', async () => {
    conUA(ANDROID)
    const { w, lib } = await montar()
    const prompt = vi.fn()
    lib.avisoInstalar.value = { prompt, userChoice: Promise.resolve({ outcome: 'accepted' }) }
    await w.vm.$nextTick()

    await w.find('[data-testid="portal-instalar-btn"]').trigger('click')
    expect(prompt).toHaveBeenCalled()
  })

  it('en iPhone le dice dónde tocar en Safari', async () => {
    conUA(IPHONE)
    const { w } = await montar()
    const pasos = w.find('[data-testid="portal-instalar-ios"]')
    expect(pasos.text()).toContain('Compartir')
    expect(pasos.text()).toContain('Agregar a inicio')
    expect(pasos.text()).toContain('Club Modelo')
  })

  it('en otro Android sin aviso, los pasos del menú', async () => {
    conUA(ANDROID)
    const { w } = await montar()
    expect(w.find('[data-testid="portal-instalar-menu"]').text()).toContain('Instalar app')
  })

  it('abierto ya como app no aparece', async () => {
    conUA(ANDROID); pwa.instalada = true
    const { w } = await montar()
    expect(w.find('[data-testid="portal-instalar"]').exists()).toBe(false)
  })

  it('en la compu no aparece', async () => {
    conUA(COMPU)
    const { w } = await montar()
    expect(w.find('[data-testid="portal-instalar"]').exists()).toBe(false)
  })

  it('«Ahora no» lo esconde, y sigue escondido al volver', async () => {
    conUA(IPHONE)
    const { w } = await montar()
    await w.find('.pin__no').trigger('click')
    expect(w.find('[data-testid="portal-instalar"]').exists()).toBe(false)
    const otra = await montar()
    expect(otra.w.find('[data-testid="portal-instalar"]').exists()).toBe(false)
  })
})

describe('La puerta queda recordada en el teléfono', () => {
  it('vuelve a la de su organización; sin recordar, a la general', async () => {
    const lib = await import('@/lib/puertaPortal')
    expect(lib.rutaDePuerta()).toBe('/paciente')
    lib.recordarPuerta('club_modelo')
    expect(lib.rutaDePuerta()).toBe('/paciente/club_modelo')
  })

  it('el manifest pasa a ser el de su organización', async () => {
    const lib = await import('@/lib/puertaPortal')
    lib.usarManifestDe('club_modelo', 'Club Modelo')
    expect(document.querySelector('link[rel="manifest"]').getAttribute('href'))
      .toMatch(/\/portal_acceso\/organizaciones\/club_modelo\/manifest$/)
  })
})
