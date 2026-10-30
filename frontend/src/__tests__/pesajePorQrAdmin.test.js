import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 30-oct-2026): «el admin pueda usar el código QR de la planta para registrar su peso;
// si es un lote en manicura, no hay otra cosa que puedas hacer con la planta más que registrarle el
// peso». Y antes (mismo día): al registrar el pesaje, dividir esa planta en uno o más frascos,
// existentes o nuevos. El admin y el supervisor escanean → pesan → eligen el frasco → queda
// confirmado y en stock. La manicura sigue con su jornada, que confirma el admin.

const api = {
  getPlantaPorQR: vi.fn(), getPlant: vi.fn(), listPlants: vi.fn(), quitarPlantaPesajeManicura: vi.fn(),
  registrarDirectoManicura: vi.fn(), listStocks: vi.fn(), listSedes: vi.fn(),
}
vi.mock('../lib/api', () => api)
vi.mock('../lib/api.js', () => api)
const registrarPesoPlantaOffline = vi.fn(() => Promise.resolve({ data: { pesaje: { id: 1 }, progreso: { pesadas: 1, total: 2, peso_total_g: 30, completado: false } } }))
vi.mock('../lib/offlineApi.js', () => ({ registrarPesoPlantaOffline }))
const registrarConJornada = vi.fn((_lote, fn) => fn({}))
vi.mock('../composables/useManicuraJornada', () => ({ useManicuraJornada: () => ({ registrarConJornada }) }))
vi.mock('../composables/useConfirm', () => ({ useConfirm: () => ({ confirm: vi.fn(() => Promise.resolve(true)) }) }))
vi.mock('../composables/useRecargaEnCambios.js', () => ({ useRecargaEnCambios: () => {} }))
const replace = vi.fn()
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { codigo_qr: 'QR-P1' } }),
  useRouter: () => ({ replace, push: vi.fn() }),
  RouterLink: { props: ['to'], template: '<a :href="String(to)"><slot /></a>' },
}))

const LOTE = { id: 5, codigo: 'L-26-101', estado: 'en_manicura' }
const PLANTA = { id: 11, nombre: '101-P1', codigo_qr: 'QR-P1', state: 'secado', peso_seco: null, lote: LOTE, genetica: { nombre: 'Gorilla Glue' } }
const FRASCOS = [{ id: 70, forma_producto: 'flor_seca', cantidad: 52, numero_lote_producto: 'ST-26-0005', calidad: 'altos', calidad_label: 'Altos' }]

beforeEach(() => {
  vi.clearAllMocks(); setActivePinia(createPinia())
  // jsdom no trae matchMedia (la compu, sin PWA).
  window.matchMedia = q => ({ matches: false, media: q, addEventListener() {}, removeEventListener() {} })
  api.getPlantaPorQR.mockResolvedValue({ data: { id: 11, nombre: '101-P1', estado: 'secado', lote: LOTE } })
  api.getPlant.mockResolvedValue({ data: PLANTA })
  api.listPlants.mockResolvedValue({ data: [PLANTA, { id: 12, nombre: '101-P2', state: 'secado', peso_seco: null }] })
  api.listStocks.mockResolvedValue({ data: FRASCOS })
  api.listSedes.mockResolvedValue({ data: [{ id: 3, nombre: 'Sede Centro' }] })
  api.registrarDirectoManicura.mockResolvedValue({ data: { stock_ids: [70, 71], lote_estado: 'en_manicura' } })
})

async function escanear(role, { qr, planta } = {}) {
  if (qr) api.getPlantaPorQR.mockResolvedValue({ data: qr })
  if (planta) api.getPlant.mockResolvedValue({ data: planta })
  const { useAuthStore } = await import('../stores/auth')
  useAuthStore().user = { id: 1, role, reglas_stock: { calidades: { altos: 'Altos', medios: 'Medios', bajos: 'Bajos', otro: 'Otro' }, calidad_obligatoria: true } }
  const { default: V } = await import('../views/PlantaQrView.vue')
  const w = mount(V, { global: { stubs: { DsSpinner: true } } })
  await flushPromises(); await flushPromises()
  return w
}
const pesoSeco = w => w.findAll('.qr__peso-input')[1]
const boton = w => w.find('.qr__btn-primary')
const fila = (w, i) => w.findAll('.rpf__fila')[i]

describe('El QR de una planta en manicura, para el admin y el supervisor', () => {
  for (const role of ['admin', 'supervisor']) {
    it(`como ${role}: lleva al pesaje (no a la ficha) y ofrece elegir el frasco`, async () => {
      const w = await escanear(role)
      expect(replace).not.toHaveBeenCalled()
      expect(w.find('.qr__peso-form').exists()).toBe(true)
      const opciones = w.find('.dfr__select--frasco').findAll('option').map(o => o.text())
      expect(opciones[0]).toBe('Frasco nuevo')
      expect(opciones[1]).toContain('ST-26-0005 · Altos')
    })
  }

  it('reparte esa planta en un frasco existente y uno nuevo, y queda registrada y en stock', async () => {
    const w = await escanear('admin')
    await pesoSeco(w).setValue(30); await flushPromises()
    await w.findAll('.dfr__link').find(b => b.text().includes('Repartir')).trigger('click'); await flushPromises()
    await fila(w, 0).find('select').setValue(70); await flushPromises()
    await fila(w, 0).find('.rpf__input--g').setValue(20); await flushPromises()
    expect(boton(w).attributes('disabled')).toBeDefined() // 20 de 30
    await fila(w, 1).find('.rpf__input--g').setValue(10); await flushPromises()
    expect(boton(w).text()).toContain('Registrar en 2 frascos')
    await boton(w).trigger('click'); await flushPromises()
    expect(api.registrarDirectoManicura).toHaveBeenCalledWith(5, {
      pesos: [{ plant_id: 11, peso_seco_g: 30 }],
      destinos: [
        { stock_id: 70, gramos: 20, descripcion: undefined, calidad: undefined },
        { stock_id: undefined, gramos: 10, descripcion: 'Bajos', calidad: 'bajos' },
      ],
    })
    expect(registrarPesoPlantaOffline).not.toHaveBeenCalled() // no va a una jornada
    const hecho = w.find('[data-testid="qr-registrado"]')
    expect(hecho.text()).toContain('Registrado y en stock')
    expect(hecho.text()).toContain('20 g a ST-26-0005 · Altos')
    expect(hecho.text()).toContain('10 g a un frasco nuevo («Bajos»)')
  })

  it('a un frasco existente, con el peso bruto al corte', async () => {
    const w = await escanear('admin')
    await w.findAll('.qr__peso-input')[0].setValue(55)
    await pesoSeco(w).setValue(30); await flushPromises()
    await w.find('.dfr__select--frasco').setValue(70); await flushPromises()
    await boton(w).trigger('click'); await flushPromises()
    expect(api.registrarDirectoManicura).toHaveBeenCalledWith(5, { pesos: [{ plant_id: 11, peso_seco_g: 30, peso_humedo_g: 55 }], stock_id: 70 })
  })

  it('a un frasco nuevo: pide la calidad antes de mandar', async () => {
    const w = await escanear('admin')
    await pesoSeco(w).setValue(30); await flushPromises()
    await boton(w).trigger('click'); await flushPromises()
    expect(api.registrarDirectoManicura).not.toHaveBeenCalled()
    expect(w.text()).toContain('Elegí la calidad')
  })

  it('si era la última planta, avisa que el lote pasó a Curado', async () => {
    api.registrarDirectoManicura.mockResolvedValue({ data: { stock_ids: [70], lote_estado: 'curado' } })
    const w = await escanear('admin')
    await pesoSeco(w).setValue(30); await flushPromises()
    await w.find('.dfr__select--frasco').setValue(70); await flushPromises()
    await boton(w).trigger('click'); await flushPromises()
    expect(w.text()).toContain('el lote pasó a Curado')
  })

  it('una planta que pesó la manicura en su jornada: dice de quién es y no se vuelve a pesar', async () => {
    const w = await escanear('admin', { planta: { ...PLANTA, peso_seco: '31.0', jornada_pesaje: { id: 9, estado: 'enviado', mia: false, de: 'Mica' } } })
    expect(w.find('[data-testid="qr-pesada-por-otra"]').text()).toContain('La pesó Mica en su jornada')
    expect(w.find('.qr__peso-form').exists()).toBe(false)
    expect(w.find('.qr__btn-editar').exists()).toBe(false)
  })

  it('una planta ya confirmada: dice dónde se corrige', async () => {
    const w = await escanear('admin', { planta: { ...PLANTA, peso_seco: '24.0', jornada_pesaje: { id: 9, estado: 'confirmado', mia: true } } })
    expect(w.text()).toContain('Editar pesaje del lote')
    expect(w.find('.qr__peso-form').exists()).toBe(false)
  })

  it('con el lote en otra fase, o la planta descartada, va a la ficha', async () => {
    await escanear('admin', { qr: { id: 11, nombre: '101-P1', estado: 'floracion', lote: { ...LOTE, estado: 'floracion' } } })
    expect(replace).toHaveBeenCalledTimes(1)
    replace.mockClear()
    await escanear('admin', { qr: { id: 11, nombre: '101-P1', estado: 'descartada', lote: LOTE } })
    expect(replace).toHaveBeenCalledTimes(1)
  })
})

describe('El QR de una planta en manicura, para la manicura', () => {
  it('pesa en su jornada (lo confirma el admin), sin elegir frasco', async () => {
    const w = await escanear('manicura')
    expect(w.find('.dfr__select--frasco').exists()).toBe(false)
    expect(api.listStocks).not.toHaveBeenCalled()
    await pesoSeco(w).setValue(31); await flushPromises()
    expect(boton(w).text()).toContain('Registrar peso')
    await boton(w).trigger('click'); await flushPromises()
    expect(registrarPesoPlantaOffline).toHaveBeenCalledWith(11, { peso_seco_g: 31 })
    expect(api.registrarDirectoManicura).not.toHaveBeenCalled()
  })
})
