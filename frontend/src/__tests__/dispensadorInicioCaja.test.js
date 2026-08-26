import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán): "un arranque de caja, el admin abre la caja, el dispensador confirma, y se
// arranca", en el Inicio del dispensador.
//
// Un build limpio no prueba que la pantalla ande: acá se MONTA el inicio con la API respondiendo
// y se recorre el flujo entero. Ya pasó cuatro veces en este proyecto que algo compilara perfecto
// y explotara al abrirse.

const analytics = {
  alcance: 'propio',
  sede_mostrador: { id: 10, nombre: 'Central' },
  resumen: { dispensaciones_hoy: 0, gramos_hoy: 0, dispensaciones_semana: 0, gramos_semana: 0, dispensaciones_mes: 0, gramos_mes: 0 },
  stocks: [], top_pacientes: [], por_dia: [],
  reservas: { hoy: 0, vencidas: 0, total: 0, lista: [] },
}

let cajaActual = null
const getCajaMostrador = vi.fn(() => Promise.resolve({ data: { caja: cajaActual } }))
const abrirCajaMostrador = vi.fn(() => Promise.resolve({ data: {} }))
const confirmarAperturaMostrador = vi.fn(() => Promise.resolve({ data: {} }))
const solicitarCierreMostrador = vi.fn(() => Promise.resolve({ data: {} }))

vi.mock('../lib/api.js', () => ({
  getAnalyticsDispensador: vi.fn(() => Promise.resolve({ data: analytics })),
  listDispensacionesFecha: vi.fn(() => Promise.resolve({ data: { dispensaciones: [] } })),
  getTareasSemana: vi.fn(() => Promise.resolve({ data: { desde: '2026-08-24', hasta: '2026-08-30', dias: [] } })),
  getCajaMostrador: (...a) => getCajaMostrador(...a),
  abrirCajaMostrador: (...a) => abrirCajaMostrador(...a),
  confirmarAperturaMostrador: (...a) => confirmarAperturaMostrador(...a),
  solicitarCierreMostrador: (...a) => solicitarCierreMostrador(...a),
  confirmarCierreMostrador: vi.fn(() => Promise.resolve({ data: {} })),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

async function montar(rol = 'dispensador') {
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 1, first_name: 'Ana', role: rol }

  const { default: Dashboard } = await import('../components/dashboards/DispensadorDashboard.vue')
  const w = mount(Dashboard, { global: { stubs: { RouterLink: { template: '<a><slot/></a>' }, DsStat: true } } })
  for (let i = 0; i < 8; i++) await new Promise((r) => setTimeout(r, 0))
  return w
}

describe('Inicio del dispensador — la caja del turno', () => {
  beforeEach(() => { vi.clearAllMocks(); cajaActual = null })

  it('sin caja abierta lo dice, y al dispensador no le ofrece abrirla', async () => {
    const w = await montar('dispensador')

    expect(w.find('.dd__caja').exists()).toBe(true)
    expect(w.text()).toContain('La caja todavía no se abrió')
    // Quien declara el fondo es quien responde por él: el botón es de administración.
    expect(w.find('.dd__caja-abrir').exists()).toBe(false)
    expect(w.text()).toContain('La abre administración')
  })

  it('el admin sí puede abrirla, con su fondo', async () => {
    const w = await montar('admin')

    expect(w.find('.dd__caja-abrir').exists()).toBe(true)
    await w.find('.dd__caja-input').setValue(10000)
    await w.find('.dd__caja-btn').trigger('click')

    expect(abrirCajaMostrador).toHaveBeenCalledWith(10, { monto_inicial_ars: 10000 })
  })

  it('abierta y sin confirmar, le pide al que atiende que confirme el fondo', async () => {
    cajaActual = { id: 7, estado: 'abierta', apertura_confirmada: false, monto_inicial_ars: 10000, abierta_por: 'Vera Admin' }
    const w = await montar('dispensador')

    expect(w.text()).toContain('Vera Admin')
    expect(w.text()).toContain('Confirmo que está el fondo')

    await w.find('.dd__caja-btn').trigger('click')
    expect(confirmarAperturaMostrador).toHaveBeenCalledWith(10, 7)
  })

  it('en marcha muestra el arqueo esperado y deja enviar el cierre', async () => {
    cajaActual = {
      id: 7, estado: 'abierta', apertura_confirmada: true, monto_inicial_ars: 10000,
      total_efectivo_ars: 4000, total_digital_ars: 3000, efectivo_esperado_ars: 14000,
    }
    const w = await montar('dispensador')

    const nums = w.find('.dd__caja-nums').text()
    expect(nums).toContain('esperado en caja')

    await w.find('.dd__caja-input').setValue(13500)
    await w.find('.dd__caja-btn').trigger('click')

    expect(solicitarCierreMostrador).toHaveBeenCalledWith(10, 7, { efectivo_declarado_ars: 13500 })
  })

  it('con el cierre enviado, sólo administración lo confirma', async () => {
    cajaActual = {
      id: 7, estado: 'pendiente_cierre', apertura_confirmada: true, monto_inicial_ars: 10000,
      efectivo_declarado_ars: 13500, diferencia_ars: -500, cierre_solicitado_por: 'Ana Mostrador',
    }
    const w = await montar('dispensador')

    expect(w.text()).toContain('Ana Mostrador')
    expect(w.text()).toContain('Faltan')
    expect(w.text()).toContain('Esperando que administración')
    expect(w.find('.dd__caja-btn').exists()).toBe(false)
  })

  // Sin sede no hay mostrador que abrir: el bloque no se dibuja en vez de romperse.
  it('sin sede de mostrador, el bloque no aparece', async () => {
    const original = analytics.sede_mostrador
    analytics.sede_mostrador = null
    const w = await montar('dispensador')

    expect(w.find('.dd__caja').exists()).toBe(false)
    analytics.sede_mostrador = original
  })
})
