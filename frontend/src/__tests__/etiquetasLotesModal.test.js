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
vi.mock('../composables/useEtiquetasQR.js', () => ({
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
const nombresPlantas = () => configPedido.tandas.find(t => t.layout.orientacion === 'portrait').items.map(p => p.nombre)

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

  it('un lote: salen su etiqueta y las banderitas de sus plantas, en ese orden', async () => {
    listPlants.mockResolvedValue({ data: [planta(2, LOTE_A, 'floracion'), planta(1, LOTE_A, 'floracion')] })
    await montar([LOTE_A])

    botonImprimir().click(); await tick()

    expect(configPedido.tandas.map(t => t.layout.orientacion)).toEqual(['landscape', 'portrait'])
    expect(configPedido.tandas[0].items.map(l => l.codigo)).toEqual(['L-26-001'])
    expect(nombresPlantas()).toEqual(expect.arrayContaining(['L-26-001-P001', 'L-26-001-P002']))
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

  // Semántica por lote: si SÓLO UNO de los lotes elegidos tiene plantas, esas salen igual.
  it('varios lotes y sólo uno con plantas: salen las de ese lote y las etiquetas de los dos', async () => {
    listPlants.mockResolvedValue({ data: [planta(5, LOTE_B, 'cosechado')] })
    await montar([LOTE_A, LOTE_B])

    botonImprimir().click(); await tick()

    expect(configPedido.tandas[0].items).toHaveLength(2)
    expect(nombresPlantas()).toEqual(['L-26-002-P005'])
  })

  it('destildando las plantas salen sólo los lotes', async () => {
    listPlants.mockResolvedValue({ data: [planta(1, LOTE_A, 'floracion')] })
    await montar([LOTE_A])

    const [, conPlantas] = checks()
    conPlantas.click(); await tick()
    botonImprimir().click(); await tick()

    expect(configPedido.tandas).toHaveLength(1)
    expect(configPedido.tandas[0].layout.orientacion).toBe('landscape')
  })

  it('destildando los lotes salen sólo las plantas', async () => {
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
    const t = configPedido.tandas[1]
    expect(t.datosDe(t.items[0], 'qr')).toMatchObject({ lote: 'L-26-001', genetica: 'Lemon', inicio: '2026-07-01' })
  })
})
