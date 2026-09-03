import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// EL ESTADO DEL MOSTRADOR EN EL INICIO DEL DISPENSADOR.
//
// La tarjeta era una SEGUNDA implementación del flujo entero —abrir con el fondo, confirmar el
// fondo, enviar el cierre, confirmarlo— viviendo en la ficha de la sede y en dos tableros. Dos
// puertas al mismo hecho es cómo dejan de coincidir, y encima ésta abría la caja **sin contar el
// stock**: declaraba un fondo y listo, salteando la mitad del arqueo.
//
// Ahora informa y manda al Mostrador, que es donde el gesto está completo.

const analytics = {
  alcance: 'propio',
  sede_mostrador: { id: 10, nombre: 'Central' },
  resumen: { dispensaciones_hoy: 0, gramos_hoy: 0, dispensaciones_semana: 0, gramos_semana: 0, dispensaciones_mes: 0, gramos_mes: 0 },
  stocks: [], top_pacientes: [], por_dia: [],
  reservas: { hoy: 0, vencidas: 0, total: 0, lista: [] },
}

let respuesta = { mesa: [], turno: null }
const getMostrador = vi.fn(() => Promise.resolve({ data: respuesta }))

vi.mock('../lib/api.js', () => ({
  getAnalyticsDispensador: vi.fn(() => Promise.resolve({ data: analytics })),
  listDispensacionesFecha: vi.fn(() => Promise.resolve({ data: { dispensaciones: [] } })),
  getTareasSemana: vi.fn(() => Promise.resolve({ data: { desde: '2026-08-24', hasta: '2026-08-30', dias: [] } })),
  getMostrador: (...a) => getMostrador(...a),
  listRendiciones: vi.fn(() => Promise.resolve({ data: { rendiciones: [] } })),
  receptoresRendicion: vi.fn(() => Promise.resolve({ data: [] })),
  crearRendicion: vi.fn(), recibirRendicion: vi.fn(), conformarRendicion: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

async function montar (rol = 'dispensador') {
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 2, role: rol }
  const { default: Dash } = await import('../components/dashboards/DispensadorDashboard.vue')
  const w = mount(Dash, { global: { stubs: { RouterLink: { template: '<a><slot/></a>' } } } })
  await flushPromises(); await flushPromises()
  return w
}

beforeEach(() => { vi.clearAllMocks(); respuesta = { mesa: [], turno: null } })

describe('El mostrador en el inicio del dispensador', () => {
  it('con la mesa vacía, dice que hay que cargarla', async () => {
    const w = await montar()

    expect(getMostrador).toHaveBeenCalledWith(10)
    expect(w.find('.cjm').text()).toContain('La mesa está vacía')
  })

  // Es el estado que más confunde: hay producto pero nadie abrió, así que no se puede dispensar.
  it('con mercadería y sin caja abierta, lo dice', async () => {
    respuesta = { mesa: [{ stock_id: 1, mostrador: 300 }], turno: null }
    const w = await montar()

    expect(w.find('.cjm').text()).toContain('Hay mercadería sobre la mesa')
  })

  it('con la caja abierta, muestra quién y cuánto se espera', async () => {
    respuesta = {
      mesa: [{ stock_id: 1, mostrador: 300 }],
      turno: { id: 7, abierto_por: 'Ana Gómez', abierto_at: '2026-09-02T12:00:00Z',
               caja: { fondo_ars: 50000, cobrado_efectivo_ars: 8500, esperado_ars: 58500 } },
    }
    const w = await montar()

    const txt = w.find('.cjm').text()
    expect(txt).toContain('Ana Gómez')
    expect(txt).toContain('producto sobre la mesa')
    expect(txt).toContain('58.500')
  })

  // UNA sola puerta: contar, abrir, cargar y cerrar pasan en Mostrador.
  it('no abre ni cierra desde acá: manda al mostrador', async () => {
    const w = await montar()

    expect(w.find('.cjm').text()).toContain('Ir al mostrador')
    expect(w.text()).not.toContain('Abrir caja')
    expect(w.text()).not.toContain('Fondo inicial')
  })
})
