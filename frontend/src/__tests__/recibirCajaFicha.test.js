import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// LA OTRA PUERTA POR LA QUE ENTRA LA PLATA DEL REPARTIDOR.
//
// "Recibir caja", en la ficha del repartidor: la usa el admin cuando el repartidor se fue sin
// rendir. Era un botón y nada más, así que la misma plata entraba distinto según por dónde
// pasara — por la rendición se elige el cajón, por acá se deducía. Ahora pregunta lo mismo.

let stats = {
  anio: 2026, mes: 9, usuario: { id: 7, nombre: 'Beto Reparto', rol: 'delivery' },
  horas: {}, produccion: {}, despachos: {}, dispensaciones: {},
  caja_delivery: { efectivo_en_mano: 200000, cobros_pendientes: 2, en_viaje: 1 },
  cajas_abiertas: [{ sede_id: 3, sede: 'Example', abierta_por: 'Dana' }],
  a_cuenta: { total_ars: 0, veces: 0, detalle: [] },
}
const USUARIO = {
  id: 7, role: 'delivery', first_name: 'Beto', last_name: 'Reparto', email: 'beto@e2e.test',
  activo: true, created_at: '2026-01-01T00:00:00Z',
}
const recibirCajaDelivery = vi.fn(() => Promise.resolve({ data: { recibido_ars: 200000, cobros: 2 } }))

vi.mock('../lib/api.js', () => ({
  getUsuarioStats:     vi.fn(() => Promise.resolve({ data: stats })),
  getUsuarioAuditorias: vi.fn(() => Promise.resolve({ data: { auditorias: [] } })),
  recibirCajaDelivery: (...a) => recibirCajaDelivery(...a),
  listJornadas:        vi.fn(() => Promise.resolve({ data: { jornadas: [] } })),
  confirmarJornadas:   vi.fn(), reabrirJornadas: vi.fn(), resetUserPassword: vi.fn(),
  saldarACuenta:       vi.fn(),
  // El store de usuarios es el que trae la ficha.
  getUser:             vi.fn(() => Promise.resolve({ data: { data: USUARIO } })),
  listUsers:           vi.fn(() => Promise.resolve({ data: [] })),
  createUser:          vi.fn(), updateUser: vi.fn(), deleteUser: vi.fn(),
  listSedes:           vi.fn(() => Promise.resolve({ data: [] })),
  listSalas:           vi.fn(() => Promise.resolve({ data: [] })),
  getSedesAsignadas:   vi.fn(() => Promise.resolve({ data: [] })),
  asignarSede:         vi.fn(), desasignarSede: vi.fn(),
  getSalasAsignadas:   vi.fn(() => Promise.resolve({ data: [] })),
  getUserSedesAsignadas: vi.fn(() => Promise.resolve({ data: [] })),
  getUserSalasAsignadas: vi.fn(() => Promise.resolve({ data: [] })),
  asignarSala:         vi.fn(), desasignarSala: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn(() => Promise.resolve(true)) }) }))
vi.mock('vue-router', () => ({
  useRoute:  () => ({ params: { id: '7' } }),
  useRouter: () => ({ push: vi.fn(), back: vi.fn() }),
  RouterLink: { template: '<a><slot /></a>' },
}))

import { useAuthStore } from '../stores/auth.js'

async function montar () {
  setActivePinia(createPinia())
  useAuthStore().user = { id: 1, role: 'admin' }
  const Vista = (await import('../views/UsuarioDetail.vue')).default
  const w = mount(Vista, { global: { stubs: { Teleport: true, AppDatePicker: true } } })
  await flushPromises()
  await flushPromises()
  return w
}

beforeEach(() => { vi.clearAllMocks() })

describe('Recibir la caja desde la ficha del repartidor', () => {
  it('pregunta en qué caja entra, con las abiertas', async () => {
    const w = await montar()
    const opciones = w.find('.udc__select').findAll('option').map(o => o.text())

    expect(opciones[0]).toContain('¿En qué caja entra?')
    expect(opciones.some(o => /Caja de Example/.test(o))).toBe(true)
    // Con un cajón abierto, llevársela es sacarla después: no es una opción del desplegable.
    expect(opciones.some(o => /organización/i.test(o))).toBe(false)
    w.unmount()
  })

  it('sin elegir la caja no deja recibir', async () => {
    const w = await montar()
    expect(w.find('.udc__recibir .udc__btn').attributes('disabled')).toBeDefined()
    w.unmount()
  })

  it('elegida la caja, viaja la sede', async () => {
    const w = await montar()
    await w.find('.udc__select').setValue('3')
    await w.find('.udc__recibir .udc__btn').trigger('click')
    await flushPromises()

    expect(recibirCajaDelivery).toHaveBeenCalledWith(7, { destino: '3' })
    w.unmount()
  })

  it('sin ninguna caja abierta sí se puede: si no, esa plata no entra nunca', async () => {
    stats = { ...stats, cajas_abiertas: [] }
    const w = await montar()
    const opciones = w.find('.udc__select').findAll('option').map(o => o.text())

    expect(opciones.some(o => /No hay ninguna caja abierta/i.test(o))).toBe(true)
    w.unmount()
  })
})
