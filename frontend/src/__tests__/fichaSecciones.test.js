import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// LA FICHA DEL PACIENTE EN SECCIONES (Germán, 28-oct-2026: «siento que tiene mil solapas, difícil
// encontrar las cosas, tendría que ser algo mucho más simple a la vista»).
//
// AC:
// - Abre en un Resumen (qué retiró, cuenta, REPROCANN, contacto) y las solapas quedan agrupadas en
//   pocas secciones: Resumen · Salud · Dispensas y cuenta · Mensajes · Datos y contacto (+ el
//   historial, chico). Dentro de cada sección, sus partes.
// - «Dispensar» y «Escribirle» están siempre en la cabecera.
// - «Para atender» junta lo que espera algo de administración con este paciente.
// - Cada rol ve sólo lo suyo: el dispensador sigue viendo sólo las dispensas, sin secciones.
// - `?tab=` sigue abriendo cualquier solapa (la abre dentro de su sección).

const route = vi.hoisted(() => ({ params: { id: '5' }, query: {} }))
vi.mock('vue-router', async (orig) => ({ ...(await orig()), useRoute: () => route }))

const PACIENTE = {
  id: 5, nombre: 'Lucía', apellido: 'Fernández', nombre_completo: 'Lucía Fernández', dni: '30111222',
  aprobado_at: '2026-01-01', es_paciente: true, telefono: '11 5555-0142', email: 'lucia@example.com',
  saldo_cc: 4500, situacion: null, acceso: { modulo: true }, pedidos_portal: 1,
  renovacion_portal: { id: 1, subida_at: '2026-10-26' },
}

const api = vi.hoisted(() => ({}))
vi.mock('../lib/api.js', () => {
  const ok = (data) => vi.fn(() => Promise.resolve({ data }))
  return {
    default: { get: ok({}), post: ok({}), patch: ok({}), put: ok({}), delete: ok({}) },
    getPaciente: vi.fn(() => Promise.resolve({ data: { data: api.paciente } })),
    listPacienteNotas: ok([]), listDispensaciones: ok({ dispensaciones: [] }), getPacienteTurnos: ok([]),
    getPacienteTimeline: ok({ timeline: [] }), updateAdminTurno: ok({}), deleteAdminTurno: ok({}), aprobarPaciente: ok({}),
  }
})

// Lo de adentro de cada solapa tiene sus propios tests: acá se prueba cómo se llega a cada una.
const STUBS = Object.fromEntries([
  'IndicacionesMedicas', 'Dispensaciones', 'PatientDocuments', 'SocioMedicos', 'SocioTabTimeline', 'SocioTabCuentaCorriente',
  'SocioTabCorreo', 'SocioTabHistoria', 'SocioTabNotas', 'SocioTabPortal', 'LinkPortalNuevo', 'ChatConPaciente',
  'RenovacionPortalCard', 'SocioTabDirecciones', 'SocioEditarModal', 'ProximoPasoReprocann', 'ModalAgendarTurnoMedico',
  'TurnoDetallePanel', 'AppDatePicker', 'Breadcrumb', 'SocioResumen', 'RouterLink',
].map((n) => [n, { template: `<div data-stub="${n}"><slot /></div>` }]))

async function abrir(role, { query = {}, paciente = PACIENTE, features = { vista_paciente: true } } = {}) {
  route.query = query
  api.paciente = paciente
  const { useAuthStore } = await import('../stores/auth')
  const { useClubStore } = await import('../stores/club')
  const { useChatPacientesStore } = await import('../stores/chatPacientes')
  useAuthStore().user = { id: 1, role }
  useClubStore().data = { features }
  const chat = useChatPacientesStore()
  chat.escuchar = vi.fn(); chat.cargar = vi.fn()
  const { default: V } = await import('../views/SocioDetailView.vue')
  const w = mount(V, { global: { stubs: STUBS } })
  await flushPromises()
  return w
}

const secciones = (w) => w.findAll('[data-testid="ficha-secciones"] button').map((b) => b.text().replace(/\d+$/, '').trim())

beforeEach(() => { setActivePinia(createPinia()) })

describe('La ficha del paciente en secciones', () => {
  it('el admin la abre en el Resumen, con cinco secciones y el historial', async () => {
    const w = await abrir('admin')
    expect(w.find('[data-stub="SocioResumen"]').exists()).toBe(true)
    expect(secciones(w)).toEqual(['Resumen', 'Salud', 'Dispensas y cuenta', 'Mensajes', 'Datos y contacto', 'Historial de la ficha'])
  })

  it('dentro de Salud están sus partes: REPROCANN, indicaciones, turnos, historia, notas, documentos', async () => {
    const w = await abrir('admin')
    await w.findAll('[data-testid="ficha-secciones"] button').find((b) => b.text().startsWith('Salud')).trigger('click')
    expect(w.findAll('.sd__subtab').map((b) => b.text().replace(/\d+$/, '').trim()))
      .toEqual(['REPROCANN', 'Indicaciones', 'Turnos', 'Historia clínica', 'Notas', 'Documentos'])
  })

  it('«Dispensar» y «Escribirle» están en la cabecera', async () => {
    const w = await abrir('admin')
    expect(w.find('[data-testid="ficha-dispensar"]').exists()).toBe(true)
    await w.find('[data-testid="ficha-escribir"]').trigger('click')
    expect(w.find('.sd__subtab--on').text()).toContain('Chat del portal')
  })

  it('«Para atender» junta el pedido del portal y la renovación, y lleva a resolverlos', async () => {
    const w = await abrir('admin')
    const franja = w.find('[data-testid="ficha-para-atender"]')
    expect(franja.text()).toContain('Pidió desde el portal')
    expect(franja.text()).toContain('Mandó su REPROCANN renovado')
    await franja.findAll('button').find((b) => b.text().includes('REPROCANN')).trigger('click')
    expect(w.find('.sd__subtab--on').text()).toContain('REPROCANN')
  })

  it('sin nada pendiente no hay franja', async () => {
    const w = await abrir('admin', { paciente: { ...PACIENTE, pedidos_portal: 0, renovacion_portal: null } })
    expect(w.find('[data-testid="ficha-para-atender"]').exists()).toBe(false)
  })

  it('?tab= abre la solapa dentro de su sección', async () => {
    const w = await abrir('admin', { query: { tab: 'cuenta_corriente' } })
    expect(w.find('.sd__sec--on').text()).toContain('Dispensas y cuenta')
    expect(w.find('.sd__subtab--on').text()).toContain('Cuenta corriente')
  })

  it('el dispensador ve sólo las dispensas: sin secciones ni Resumen', async () => {
    const w = await abrir('dispensador')
    expect(w.find('[data-testid="ficha-secciones"]').exists()).toBe(false)
    expect(w.find('[data-stub="SocioResumen"]').exists()).toBe(false)
    expect(w.find('[data-stub="Dispensaciones"]').exists()).toBe(true)
  })

  it('sin el portal contratado no hay sección Mensajes de portal: queda el correo', async () => {
    const w = await abrir('admin', { paciente: { ...PACIENTE, acceso: { modulo: false } }, features: {} })
    await w.findAll('[data-testid="ficha-secciones"] button').find((b) => b.text().startsWith('Mensajes')).trigger('click')
    expect(w.findAll('.sd__subtab').length).toBe(0) // una sola parte: el correo, sin pestañas
    expect(w.find('[data-stub="SocioTabCorreo"]').exists()).toBe(true)
  })

  it('el médico no ve Dispensas y cuenta ni Mensajes', async () => {
    const w = await abrir('medico')
    expect(secciones(w)).not.toContain('Mensajes')
    expect(secciones(w)).toContain('Salud')
  })
})
