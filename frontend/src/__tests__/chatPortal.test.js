import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createMemoryHistory } from 'vue-router'

// EL CHAT DEL PORTAL, LAS PANTALLAS (27-oct-2026).
//
// AC:
//   - Burbujas mías a la derecha y del otro a la izquierda, separadas por día; mis mensajes con ✓
//     y ✓✓ en azul cuando el otro lado ya leyó hasta ahí.
//   - Enter manda (Shift+Enter es un renglón nuevo); vacío no manda.
//   - «Consultar por esta dispensa» manda el mensaje citándola.
//   - Del lado del equipo: un mensaje nuevo de un paciente levanta la alerta con su nombre, salvo
//     que esa conversación esté abierta; el contador cuenta las que esperan respuesta.

const api = vi.hoisted(() => ({
  listChatPacientes: vi.fn(), getPortalMensajes: vi.fn(), enviarPortalMensaje: vi.fn(),
  marcarPortalMensajesLeidos: vi.fn(), getPortalDispensa: vi.fn(),
}))
vi.mock('../lib/api', () => ({ listChatPacientes: (...a) => api.listChatPacientes(...a) }))
vi.mock('../lib/portalApi', () => ({
  getPortalMensajes: (...a) => api.getPortalMensajes(...a),
  enviarPortalMensaje: (...a) => api.enviarPortalMensaje(...a),
  marcarPortalMensajesLeidos: (...a) => api.marcarPortalMensajesLeidos(...a),
}))
vi.mock('@/lib/portalApi', () => ({
  getPortalMensajes: (...a) => api.getPortalMensajes(...a),
  enviarPortalMensaje: (...a) => api.enviarPortalMensaje(...a),
  marcarPortalMensajesLeidos: (...a) => api.marcarPortalMensajesLeidos(...a),
  getPortalDispensa: (...a) => api.getPortalDispensa(...a),
}))
const cable = vi.hoisted(() => ({ handlers: {}, avisos: [] }))
vi.mock('../lib/cambios.js', () => ({
  alCambiar: (recurso, fn) => { cable.handlers[recurso] = fn; return () => {} },
  avisarAlCanal: (accion, datos) => cable.avisos.push([accion, datos]),
}))
vi.mock('@/composables/useToast', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))

const ChatHilo = (await import('../components/chat/ChatHilo.vue')).default
const { useChatPacientesStore } = await import('../stores/chatPacientes')

const hace = (min) => new Date(Date.now() - min * 60000).toISOString()
const MENSAJES = [
  { id: 1, autor: 'paciente', texto: '¿El jueves puedo pasar 19:30?', at: hace(60 * 26) },
  { id: 2, autor: 'organizacion', quien: 'Javier', texto: 'Sí, te lo dejamos hasta las 20.', at: hace(60 * 25) },
  { id: 3, autor: 'paciente', texto: 'Genial, gracias!', at: hace(10) },
]

const router = createRouter({ history: createMemoryHistory(), routes: [{ path: '/:p(.*)*', component: { template: '<div/>' } }] })

beforeEach(() => {
  setActivePinia(createPinia())
  Object.values(api).forEach((f) => f.mockReset())
  cable.handlers = {}
  cable.avisos = []
})

describe('Las burbujas', () => {
  const montar = (props) => mount(ChatHilo, { props: { lado: 'paciente', mensajes: MENSAJES, ...props }, global: { plugins: [router] } })

  it('las mías a la derecha, las del otro a la izquierda firmadas por quien contestó, con el día', () => {
    const w = montar()
    expect(w.findAll('[data-testid="msj-mio"]').map((b) => b.find('.ch__texto').text())).toEqual(['¿El jueves puedo pasar 19:30?', 'Genial, gracias!'])
    expect(w.find('[data-testid="msj-otro"]').text()).toContain('Javier')
    expect(w.findAll('.ch__dia').map((d) => d.text())).toEqual(['Ayer', 'Hoy'])
  })

  it('✓✓ en azul en lo que el otro lado ya leyó; ✓ en lo que no', () => {
    const w = montar({ leidoHasta: hace(30) })
    const tildes = w.findAll('[data-testid="msj-mio"] .ch__tilde')
    expect(tildes[0].text()).toBe('✓✓')
    expect(tildes[0].classes()).toContain('ch__tilde--leido')
    expect(tildes[1].text()).toBe('✓')
  })

  it('Enter manda y vacía; Shift+Enter no manda; vacío no manda', async () => {
    const w = montar()
    const ta = w.find('textarea')
    await ta.trigger('keydown', { key: 'Enter' })
    expect(w.emitted('enviar')).toBeUndefined()

    await ta.setValue('Hola')
    await ta.trigger('keydown', { key: 'Enter', shiftKey: true })
    expect(w.emitted('enviar')).toBeUndefined()

    await ta.trigger('keydown', { key: 'Enter' })
    expect(w.emitted('enviar')[0][0]).toEqual({ texto: 'Hola', archivo: null })
    expect(ta.element.value).toBe('')
  })

  it('«está escribiendo» se ve como burbuja del otro lado', () => {
    const w = montar({ escribiendo: 'Javier está escribiendo…' })
    expect(w.find('.ch__puntos').attributes('aria-label')).toBe('Javier está escribiendo…')
  })
})

describe('El chat del paciente', () => {
  it('«Consultar por esta dispensa» la cita, y el mensaje sale con ella', async () => {
    api.getPortalMensajes.mockResolvedValue({ data: [], conversacion: {}, sin_leer: 0 })
    api.getPortalDispensa.mockResolvedValue({ id: 842, numero: '0842', items: [{ nombre: 'Northern Lights', cantidad: 5, unidad: 'g' }] })
    api.enviarPortalMensaje.mockResolvedValue({ id: 9, autor: 'paciente', texto: 'Hola', at: new Date().toISOString() })
    await router.push('/portal/mensajes?dispensa=842')
    const V = (await import('../views/portal/PortalMensajesView.vue')).default
    const w = mount(V, { global: { plugins: [router] } })
    await flushPromises()

    expect(w.text()).toContain('Dispensa Nº 0842')
    await w.find('textarea').setValue('Una consulta')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(api.enviarPortalMensaje).toHaveBeenCalledWith({ texto: 'Una consulta', archivo: null, dispensacionId: 842 })
  })

  it('al abrirlo marca leído lo que tenía sin leer', async () => {
    api.getPortalMensajes.mockResolvedValue({ data: MENSAJES, conversacion: {}, sin_leer: 1 })
    api.marcarPortalMensajesLeidos.mockResolvedValue({})
    await router.push('/portal/mensajes')
    const V = (await import('../views/portal/PortalMensajesView.vue')).default
    mount(V, { global: { plugins: [router] } })
    await flushPromises()

    expect(api.marcarPortalMensajesLeidos).toHaveBeenCalled()
  })
})

describe('Del lado del equipo', () => {
  const fila = (id, nombre, autor, at, extra = {}) => ({
    paciente: { id, nombre, apellido: 'Fernández' }, ultimo: { autor, texto: 'Hola! Ya subí la constancia', at },
    sin_leer: autor === 'paciente' ? 1 : 0, sin_responder: autor === 'paciente', resuelta: false, ...extra,
  })

  it('un mensaje nuevo de un paciente levanta la alerta con su nombre y lo que escribió', async () => {
    const chat = useChatPacientesStore()
    api.listChatPacientes.mockResolvedValueOnce({ data: { data: [], sin_responder: 0 } })
    await chat.cargar()
    chat.escuchar()

    api.listChatPacientes.mockResolvedValueOnce({ data: { data: [fila(7, 'Lucía', 'paciente', hace(0))], sin_responder: 1 } })
    cable.handlers.mensajes({ recurso: 'mensajes', accion: 'creado', id: 7 })
    await flushPromises()

    expect(chat.sinResponder).toBe(1)
    expect(chat.alerta).toEqual({ pacienteId: 7, nombre: 'Lucía Fernández', texto: 'Hola! Ya subí la constancia' })
  })

  it('si esa conversación está abierta, no hay alerta', async () => {
    const chat = useChatPacientesStore()
    chat.escuchar()
    chat.abiertoPacienteId = 7
    api.listChatPacientes.mockResolvedValue({ data: { data: [fila(7, 'Lucía', 'paciente', hace(0))], sin_responder: 1 } })
    cable.handlers.mensajes({ recurso: 'mensajes', accion: 'creado', id: 7 })
    await flushPromises()

    expect(chat.alerta).toBeNull()
  })

  it('una respuesta del equipo no es una alerta', async () => {
    const chat = useChatPacientesStore()
    chat.escuchar()
    api.listChatPacientes.mockResolvedValue({ data: { data: [fila(7, 'Lucía', 'organizacion', hace(0))], sin_responder: 0 } })
    cable.handlers.mensajes({ recurso: 'mensajes', accion: 'creado', id: 7 })
    await flushPromises()

    expect(chat.alerta).toBeNull()
  })

  it('«está escribiendo» se prende para ese paciente sin re-pedir nada', () => {
    const chat = useChatPacientesStore()
    chat.escuchar()
    cable.handlers.mensajes({ recurso: 'mensajes', accion: 'escribiendo', id: 7 })
    expect(chat.escribiendo[7]).toBe(true)
    expect(api.listChatPacientes).not.toHaveBeenCalled()
  })
})
