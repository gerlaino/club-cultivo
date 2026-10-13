import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// AC (Germán, 12-oct-2026): super admin genera un link de Mercado Pago POR ORGANIZACIÓN con su
// monto; el autocultivo se suscribe solo, al precio fijo que carga super admin, y se va a Mercado
// Pago a completar.
const api = vi.hoisted(() => ({
  getMiSuscripcion: vi.fn(), crearMiSuscripcion: vi.fn(),
  getSuscripcionClub: vi.fn(), crearSuscripcionClub: vi.fn(), cancelarSuscripcionClub: vi.fn(),
}))
vi.mock('../lib/api.js', () => Object.fromEntries(Object.keys(api).map(k => [k, (...a) => api[k](...a)])))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn(() => Promise.resolve(true)) }) }))

beforeEach(() => Object.values(api).forEach(f => f.mockReset()))

describe('Autocultivo: Mi suscripción', () => {
  async function montar(datos) {
    api.getMiSuscripcion.mockResolvedValue({ data: { precio_ars: 9900, mp_configurado: true, actual: null, plan_activo_hasta: '2026-11-11', en_prueba: true, email_sugerido: 'yo@casa.com', ...datos } })
    const { default: C } = await import('../components/personal/MiSuscripcion.vue')
    const w = mount(C)
    await flushPromises()
    return w
  }

  it('muestra el precio fijo y el mail sugerido', async () => {
    const w = await montar()
    expect(w.text()).toContain('9.900')
    expect(w.find('input[type="email"]').element.value).toBe('yo@casa.com')
  })

  it('«Suscribirme» manda sólo el mail y se va al link de Mercado Pago', async () => {
    api.crearMiSuscripcion.mockResolvedValue({ data: { link: 'https://mp.test/sub/1' } })
    const original = window.location
    delete window.location
    window.location = { href: '' }
    const w = await montar()
    await w.find('input[type="email"]').setValue('mi.mp@gmail.com')
    await w.find('button').trigger('click')
    await flushPromises()
    expect(api.crearMiSuscripcion).toHaveBeenCalledWith({ payer_email: 'mi.mp@gmail.com' })
    expect(window.location.href).toBe('https://mp.test/sub/1')
    window.location = original
  })

  it('sin precio cargado o sin Mercado Pago, no ofrece suscribirse: dice que escriba', async () => {
    const w = await montar({ precio_ars: null })
    expect(w.find('button').exists()).toBe(false)
    expect(w.text()).toContain('escribinos')
  })

  it('activa: lo dice, con hasta cuándo está pagado', async () => {
    const w = await montar({ actual: { estado: 'activa', monto_ars: 9900, payer_email: 'mi.mp@gmail.com' } })
    expect(w.text()).toContain('Suscripción activa')
    expect(w.text()).toContain('11 de noviembre')
    expect(w.find('button').exists()).toBe(false)
  })
})

describe('Super admin: cobro de una organización', () => {
  it('genera el link con el monto y el mail, y lo deja para copiar', async () => {
    api.getSuscripcionClub.mockResolvedValue({ data: { mp_configurado: true, actual: null, email_sugerido: 'admin@mito.org' } })
    api.crearSuscripcionClub.mockResolvedValue({ data: { id: 1, estado: 'pendiente', estado_label: 'Esperando que se suscriba', monto_ars: 350000, payer_email: 'admin@mito.org', link: 'https://mp.test/sub/9', cobros: [] } })
    const { default: C } = await import('../components/superadmin/SACobroMercadoPago.vue')
    const w = mount(C, { props: { clubId: 5 } })
    await flushPromises()

    await w.findAll('button').find(b => b.text().includes('Generar link de cobro')).trigger('click')
    await w.find('input[type="number"]').setValue(350000)
    await w.findAll('button').find(b => b.text() === 'Generar link').trigger('click')
    await flushPromises()

    expect(api.crearSuscripcionClub).toHaveBeenCalledWith(5, { monto_ars: 350000, payer_email: 'admin@mito.org' })
    expect(w.find('input[readonly]').element.value).toBe('https://mp.test/sub/9')
  })

  it('sin Mercado Pago configurado, dice qué falta y no ofrece generar', async () => {
    api.getSuscripcionClub.mockResolvedValue({ data: { mp_configurado: false, actual: null } })
    const { default: C } = await import('../components/superadmin/SACobroMercadoPago.vue')
    const w = mount(C, { props: { clubId: 5 } })
    await flushPromises()
    expect(w.text()).toContain('MP_ACCESS_TOKEN')
    expect(w.findAll('button').some(b => b.text().includes('Generar'))).toBe(false)
  })
})
