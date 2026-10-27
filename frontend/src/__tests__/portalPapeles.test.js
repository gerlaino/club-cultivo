import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// LA RENOVACIÓN DEL REPROCANN DESDE EL PORTAL, LAS PANTALLAS (27-oct-2026).
//
// AC: el paciente ve su REPROCANN y sube la constancia; ve si quedó en revisión, aprobada o
// rechazada (con el motivo). En la ficha, administración la ve y la aprueba con la fecha nueva o
// la devuelve con el motivo; sin permiso, no se le ofrece.

const api = vi.hoisted(() => ({ getPortalPapeles: vi.fn(), subirRenovacionReprocann: vi.fn(), updateReprocannRenovacion: vi.fn() }))
vi.mock('@/lib/portalApi', () => ({
  getPortalPapeles: (...a) => api.getPortalPapeles(...a),
  subirRenovacionReprocann: (...a) => api.subirRenovacionReprocann(...a),
}))
vi.mock('../lib/api.js', () => ({ updateReprocannRenovacion: (...a) => api.updateReprocannRenovacion(...a) }))
vi.mock('@/lib/cambios.js', () => ({ alCambiar: () => () => {} }))
vi.mock('@/lib/imagenes.js', () => ({ achicarImagen: async (f) => f }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))

const PortalReprocannCard = (await import('../components/portal/PortalReprocannCard.vue')).default
const RenovacionPortalCard = (await import('../components/pacientes/RenovacionPortalCard.vue')).default

const REPROCANN = { numero: 'R-1', vencimiento: '2026-11-03', dias_para_vencer: 7, categoria: 'por_vencer' }

beforeEach(() => Object.values(api).forEach((f) => f.mockReset()))

describe('Mi REPROCANN, en el portal', () => {
  it('por vencer: lo dice y ofrece subir la constancia; al subirla queda en revisión', async () => {
    api.getPortalPapeles.mockResolvedValueOnce({ reprocann: REPROCANN, renovacion: null })
    const w = mount(PortalReprocannCard)
    await flushPromises()
    expect(w.find('[data-testid="reprocann-estado"]').text()).toBe('Por vencer')

    api.subirRenovacionReprocann.mockResolvedValue({ id: 1, estado: 'en_tramite' })
    api.getPortalPapeles.mockResolvedValueOnce({ reprocann: REPROCANN, renovacion: { estado: 'en_tramite', subida_at: '2026-10-27T13:00:00Z' } })
    const archivo = new File(['%PDF'], 'constancia.pdf', { type: 'application/pdf' })
    const input = w.find('input[type="file"]')
    Object.defineProperty(input.element, 'files', { value: [archivo] })
    await input.trigger('change')
    await flushPromises()

    expect(api.subirRenovacionReprocann).toHaveBeenCalledWith(archivo)
    expect(w.find('[data-testid="reprocann-estado"]').text()).toBe('Renovación en revisión')
    expect(w.find('[data-testid="renovacion-en-revision"]').text()).toContain('seguís retirando')
  })

  it('rechazada: muestra el motivo y pide subirla de nuevo', async () => {
    api.getPortalPapeles.mockResolvedValue({ reprocann: REPROCANN, renovacion: { estado: 'rechazada', observaciones: 'La foto no se lee.' } })
    const w = mount(PortalReprocannCard)
    await flushPromises()
    expect(w.text()).toContain('«La foto no se lee.»')
    expect(w.text()).toContain('Subila de nuevo')
  })
})

describe('La renovación en la ficha', () => {
  const RENOV = { id: 9, subida_at: '2026-10-27T13:00:00Z', constancia_url: '/c.pdf', constancia_nombre: 'constancia.pdf', es_imagen: false }

  it('aprobar manda la fecha nueva (y el número si cambió) y avisa a la ficha', async () => {
    api.updateReprocannRenovacion.mockResolvedValue({ data: {} })
    const w = mount(RenovacionPortalCard, { props: { socioId: 7, renovacion: RENOV, numeroActual: 'R-1', puedeRevisar: true } })

    expect(w.find('[data-testid="renovacion-aprobar"]').attributes('disabled')).toBeDefined()
    await w.find('[data-testid="renovacion-vencimiento"]').setValue('2027-11-03')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(api.updateReprocannRenovacion).toHaveBeenCalledWith(7, 9, { accion: 'aprobar', fecha_vencimiento_nueva: '2027-11-03', reprocann_numero_nuevo: undefined })
    expect(w.emitted('revisada')).toBeTruthy()
  })

  it('devolverla pide el motivo, que es lo que lee el paciente', async () => {
    api.updateReprocannRenovacion.mockResolvedValue({ data: {} })
    const w = mount(RenovacionPortalCard, { props: { socioId: 7, renovacion: RENOV, puedeRevisar: true } })

    await w.findAll('button').find((b) => b.text() === 'No se puede aprobar').trigger('click')
    await w.find('textarea').setValue('La foto no se lee, subila de nuevo.')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(api.updateReprocannRenovacion).toHaveBeenCalledWith(7, 9, { accion: 'rechazar', observaciones: 'La foto no se lee, subila de nuevo.' })
  })

  it('sin permiso para revisarla, ve la constancia pero no los botones', () => {
    const w = mount(RenovacionPortalCard, { props: { socioId: 7, renovacion: RENOV, puedeRevisar: false } })
    expect(w.find('a').attributes('href')).toBe('/c.pdf')
    expect(w.find('form').exists()).toBe(false)
  })
})
