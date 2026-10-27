import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

const invitar = vi.fn(() => Promise.resolve({ data: { link: {
  url: 'https://cultivoespacial.com/portal/entrar/abc123', texto: 'Hola Ana! Te invitamos… https://cultivoespacial.com/portal/entrar/abc123',
  expira_at: '2026-10-30T15:00:00Z', mail_enviado: false,
} } }))
const confirmar = vi.fn(() => Promise.resolve(true))

vi.mock('../lib/api.js', () => ({ invitarPortalPaciente: (...a) => invitar(...a) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: confirmar }) }))
vi.mock('../composables/useToast', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn() }) }))

const SocioTabPortal = (await import('../components/pacientes/SocioTabPortal.vue')).default

const base = { modulo: true, portal_abierto: true, activo: true, activado: false, link_vigente: null,
               ultimo_ingreso: null, tiene_mail: false, puede_gestionar: true }
const montar = (acceso) => mount(SocioTabPortal, {
  props: { socioId: 7, nombre: 'Ana Díaz', acceso: { ...base, ...acceso } },
  global: { directives: { modal: {} } },
  attachTo: document.body,
})
const boton = (w) => w.find('[data-testid="portal-invitar"]')

// AC (27-oct-2026): desde la ficha se le manda al paciente el LINK para entrar a su portal (elige
// su clave con su DNI). La ficha dice en qué está: sin invitar, invitado, activado o cerrado. Nadie
// ve ni dicta una contraseña.
describe('Acceso al portal, en la ficha del paciente', () => {
  beforeEach(() => { invitar.mockClear(); confirmar.mockClear(); document.body.innerHTML = '' })

  it('al que nunca invitaron le ofrece «Invitar al portal» y muestra el link para mandar', async () => {
    const w = montar({})
    expect(w.find('[data-testid="portal-estado"]').text()).toBe('Sin invitar')
    expect(boton(w).text()).toContain('Invitar al portal')

    await boton(w).trigger('click')
    await flushPromises()

    expect(invitar).toHaveBeenCalledWith(7)
    expect(confirmar).not.toHaveBeenCalled()
    expect(document.body.querySelector('[data-testid="link-portal"]').textContent).toContain('/portal/entrar/abc123')
    // Para WhatsApp, el mensaje entero (con el link) va en el texto del enlace.
    const wa = document.body.querySelector('[data-testid="link-portal-whatsapp"]').getAttribute('href')
    expect(decodeURIComponent(wa)).toContain('/portal/entrar/abc123')
  })

  it('no muestra ni pide ninguna contraseña', () => {
    const w = montar({})
    expect(w.text().toLowerCase()).not.toContain('contraseña')
  })

  it('con un link vigente sin usar, mandar otro pregunta antes: el anterior deja de servir', async () => {
    const w = montar({ link_vigente: { motivo: 'invitacion', creado_at: '2026-10-27T15:00:00Z', expira_at: '2026-10-30T15:00:00Z' } })
    expect(w.find('[data-testid="portal-estado"]').text()).toBe('Invitado, sin activar')
    expect(boton(w).text()).toContain('Mandar un link nuevo')

    await boton(w).trigger('click')
    await flushPromises()

    expect(confirmar).toHaveBeenCalled()
    expect(invitar).toHaveBeenCalled()
  })

  it('el que ya lo activó: dice cuándo entró y que la clave la recupera solo', () => {
    const w = montar({ activado: true, ultimo_ingreso: '2026-10-27T13:14:00Z', tiene_mail: true })
    expect(w.find('[data-testid="portal-estado"]').text()).toBe('Activó su portal')
    expect(w.text()).toContain('Entró')
    expect(w.text()).toContain('Me olvidé la clave')
  })

  it('dado de baja, lo dice y no ofrece mandar un link que no abriría', () => {
    const w = montar({ activo: false })
    expect(w.find('[data-testid="portal-estado"]').text()).toBe('Dado de baja')
    expect(boton(w).exists()).toBe(false)
  })

  it('con el portal cerrado, dice dónde abrirlo y no ofrece el link', () => {
    const w = montar({ portal_abierto: false })
    expect(w.text()).toContain('Configuración → Portal del paciente')
    expect(boton(w).exists()).toBe(false)
  })

  it('a quien no puede gestionarlo no le ofrece un botón que rebota', () => {
    const w = montar({ puede_gestionar: false })
    expect(boton(w).exists()).toBe(false)
    expect(w.text()).toContain('Sólo administración')
  })
})
