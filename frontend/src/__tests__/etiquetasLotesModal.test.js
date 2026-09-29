import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { ref, computed } from 'vue'
import { vModal } from '../directives/modal.js'

// AC (Germán, 29-sep): en /lotes elijo uno o más lotes, toco «Imprimir etiquetas» y un modal me
// pregunta si van también los QR de las plantas. Las DESCARTADAS no se imprimen; las COSECHADAS sí
// (reimprimir las de un lote cosechado es un caso real).

const listPlants = vi.fn()
vi.mock('../lib/api.js', () => ({ listPlants: (...a) => listPlants(...a) }))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn() }),
}))
vi.mock('../stores/club.js', () => ({
  useClubStore: () => ({ data: { name: 'Org' }, fetch: vi.fn(() => Promise.resolve()) }),
}))

// Se captura el config que la pantalla le pasa al generador: lo que importa es QUÉ se manda a
// imprimir, no cómo dibuja jsPDF (eso lo cubre etiquetasTanda.test.js).
let configPedido = null
vi.mock('../composables/useEtiquetasQR.js', async (original) => ({
  ...(await original()),
  useEtiquetasQR: () => ({
    ocupado: ref(false), titulo: computed(() => ''), hechas: ref(0), total: ref(0),
    imprimir:  async (cfg) => { configPedido = await cfg(); return { ok: true } },
    descargar: async (cfg) => { configPedido = await cfg(); return { ok: true } },
  }),
}))

const EtiquetasLotesModal = (await import('../components/lotes/EtiquetasLotesModal.vue')).default

const LOTE_A = { id: 1, codigo: 'L-26-001', codigo_qr: 'la', estado: 'floracion', start_date: '2026-07-01', genetica: { nombre: 'Lemon' } }
const LOTE_B = { id: 2, codigo: 'L-26-002', codigo_qr: 'lb', estado: 'cosecha',   start_date: '2026-05-01', genetica: { nombre: 'Kush' } }

const planta = (id, lote, state, qr = `p${id}`) =>
  ({ id, nombre: `${lote.codigo}-P${String(id).padStart(3, '0')}`, codigo_qr: qr, state, lote: { id: lote.id, codigo: lote.codigo } })

const $  = (sel) => document.body.querySelector(sel)
const $$ = (sel) => [...document.body.querySelectorAll(sel)]
const tick = () => new Promise(r => setTimeout(r, 0))

async function montar(lotes) {
  const wrapper = mount(EtiquetasLotesModal, {
    props: { show: false, lotes },
    global: { directives: { modal: vModal }, stubs: { BloqueoProgreso: true } },
    attachTo: document.body,
  })
  // Se abre después de montar, como en la app: las plantas se piden en el watch de `show`.
  await wrapper.setProps({ show: true })
  await tick(); await wrapper.vm.$nextTick()
  return wrapper
}

const botonImprimir = () => $$('.elm__btn--main')[0]
const checks = () => $$('.elm__opt input[type=checkbox]')
// Lo que sale, en orden: 'LOTE L-26-001', 'L-26-001-P001', …
const secuencia = () => configPedido.secuencia.map(({ item }) => item.nombre ?? `LOTE ${item.codigo}`)
const nombresPlantas = () => secuencia().filter(s => !s.startsWith('LOTE'))

describe('EtiquetasLotesModal', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    document.body.innerHTML = ''
    configPedido = null
    listPlants.mockReset()
  })

  it('pide las plantas de TODOS los lotes elegidos, de una', async () => {
    listPlants.mockResolvedValue({ data: [] })
    await montar([LOTE_A, LOTE_B])
    expect(listPlants).toHaveBeenCalledWith({ lote_ids: [1, 2] })
  })

  it('un lote: sale su etiqueta y debajo las de sus plantas, en orden', async () => {
    listPlants.mockResolvedValue({ data: [planta(2, LOTE_A, 'floracion'), planta(1, LOTE_A, 'floracion')] })
    await montar([LOTE_A])

    botonImprimir().click(); await tick()

    expect(secuencia()).toEqual(['LOTE L-26-001', 'L-26-001-P001', 'L-26-001-P002'])
    // La etiqueta del lote no queda sola al pie de una hoja: va pegada a su primera planta.
    expect(configPedido.secuencia[0].pegadoAlSiguiente).toBe(true)
  })

  // AC (Germán, 29-sep): «qr del lote, qr de las plantas de ese lote, y así sucesivamente».
  it('varios lotes: intercalados, cada lote seguido de SUS plantas', async () => {
    // Llegan mezcladas y con los lotes elegidos en otro orden.
    listPlants.mockResolvedValue({ data: [
      planta(4, LOTE_B, 'cosechado'), planta(1, LOTE_A, 'floracion'),
      planta(3, LOTE_B, 'cosechado'), planta(2, LOTE_A, 'floracion'),
    ] })
    await montar([LOTE_B, LOTE_A])

    botonImprimir().click(); await tick()

    expect(secuencia()).toEqual([
      'LOTE L-26-001', 'L-26-001-P001', 'L-26-001-P002',
      'LOTE L-26-002', 'L-26-002-P003', 'L-26-002-P004',
    ])
  })

  it('un lote sin plantas sale igual, y no se pega a las del lote siguiente', async () => {
    listPlants.mockResolvedValue({ data: [planta(1, LOTE_B, 'cosechado')] })
    await montar([LOTE_A, LOTE_B])

    botonImprimir().click(); await tick()

    expect(secuencia()).toEqual(['LOTE L-26-001', 'LOTE L-26-002', 'L-26-002-P001'])
    expect(configPedido.secuencia[0].pegadoAlSiguiente).toBe(false)
  })

  it('un lote sin QR no lleva etiqueta, pero sus plantas salen en su lugar', async () => {
    const sinQR = { ...LOTE_A, codigo_qr: null }
    listPlants.mockResolvedValue({ data: [planta(1, sinQR, 'floracion'), planta(2, LOTE_B, 'floracion')] })
    await montar([sinQR, LOTE_B])

    botonImprimir().click(); await tick()

    expect(secuencia()).toEqual(['L-26-001-P001', 'LOTE L-26-002', 'L-26-002-P002'])
  })

  it('las descartadas quedan afuera y las cosechadas entran', async () => {
    listPlants.mockResolvedValue({ data: [
      planta(1, LOTE_A, 'floracion'),
      planta(2, LOTE_A, 'descartada'),
      planta(3, LOTE_B, 'cosechado'),
    ] })
    await montar([LOTE_A, LOTE_B])

    expect($('.elm__body').textContent).toContain('1 descartadas quedan afuera')
    botonImprimir().click(); await tick()

    expect(nombresPlantas()).toEqual(['L-26-001-P001', 'L-26-002-P003'])
  })

  it('destildando las plantas salen sólo los lotes, en su plancha apaisada', async () => {
    listPlants.mockResolvedValue({ data: [planta(1, LOTE_A, 'floracion')] })
    await montar([LOTE_A])

    const [, conPlantas] = checks()
    conPlantas.click(); await tick()
    botonImprimir().click(); await tick()

    expect(configPedido.tandas).toHaveLength(1)
    expect(configPedido.tandas[0].layout.orientacion).toBe('landscape')
  })

  it('destildando los lotes salen sólo las plantas, en su plancha vertical', async () => {
    listPlants.mockResolvedValue({ data: [planta(1, LOTE_A, 'floracion')] })
    await montar([LOTE_A])

    const [conLotes] = checks()
    conLotes.click(); await tick()
    botonImprimir().click(); await tick()

    expect(configPedido.tandas).toHaveLength(1)
    expect(configPedido.tandas[0].layout.orientacion).toBe('portrait')
  })

  it('una planta sin QR no se imprime y se avisa', async () => {
    listPlants.mockResolvedValue({ data: [planta(1, LOTE_A, 'floracion'), planta(2, LOTE_A, 'floracion', null)] })
    await montar([LOTE_A])

    expect($('.elm__body').textContent).toContain('1 sin QR: no se imprimen')
    botonImprimir().click(); await tick()
    expect(nombresPlantas()).toEqual(['L-26-001-P001'])
  })

  it('la banderita lleva la genética y el inicio del lote', async () => {
    listPlants.mockResolvedValue({ data: [planta(1, LOTE_A, 'floracion')] })
    await montar([LOTE_A])

    botonImprimir().click(); await tick()
    const { item, pieza } = configPedido.secuencia[1]
    expect(pieza.datosDe(item, 'qr')).toMatchObject({ lote: 'L-26-001', genetica: 'Lemon', inicio: '2026-07-01' })
  })
})
