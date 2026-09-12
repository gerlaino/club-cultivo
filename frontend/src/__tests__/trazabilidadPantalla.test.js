import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// LA PANTALLA DE TRAZABILIDAD DIBUJA LO QUE EL BACKEND MANDA. La cronología del lote leyó durante
// meses una clave (`lote_eventos`) que el backend nunca envió y mostraba sólo la pesada, y nadie
// lo vio porque no había un test que pegara el payload real. Este pega el de `Stocks::Trazabilidad`
// con los MISMOS nombres de clave y fija lo que se decidió en sep-2026: la cuenta con las salidas
// nombradas, la oración, la cronología viva, el DNI en tres dígitos y «siguió en».
const getStockTrazabilidad = vi.fn()
const listStocks = vi.fn()
vi.mock('../lib/api.js', () => ({
  default: { get: vi.fn() },
  getStockTrazabilidad: (...a) => getStockTrazabilidad(...a),
  listStocks: (...a) => listStocks(...a),
}))
vi.mock('../lib/descargas.js', () => ({ descargarArchivo: vi.fn() }))

const PAYLOAD = {
  stock: {
    id: 41, numero_lote_producto: 'ST-26-041', forma_producto: 'flor_seca', unidad: 'g', origen: 'lote',
    proveedor: null, sede: 'Central', cantidad_inicial_g: 612, cantidad_disponible_g: 97.5,
    fecha_elaboracion: '2026-08-14', codigo_qr: 'ST26041-9F2A',
    genetica: { id: 1, nombre: 'Critical Kush', nombre_propio: 'Critical Kush', declarada: false, numero_registro_inase: null, tipo: 'indica', thc: 18, cbd: 0.5 },
    producido_desde: null,
  },
  lote: { id: 31, codigo: 'L-26-031', estado: 'en_manicura', genetica: { nombre: 'Critical Kush', nombre_propio: 'Critical Kush', declarada: false, numero_registro_inase: null } },
  aplicaciones: { registros: 0 },
  analisis_laboratorio: [{ fecha: '2026-09-02', laboratorio: 'Cannalab', thc_pct: 16.4, cbd_pct: 0.3, cbg_pct: null, terpenos: null }],
  pesada: null,
  plantas: [{ id: 1, codigo_qr: 'P-0398', origen: 'semilla', peso_g: 36.2, promedio: false }],
  atribucion: 'planta',
  plantas_descartadas: [],
  cronologia: [
    { fecha: '2026-05-18T10:00:00Z', tipo: 'estado', estado: 'vegetativo', titulo: 'vegetativo', detalle: null },
    { fecha: '2026-06-22T10:00:00Z', tipo: 'estado', estado: 'floracion', titulo: 'floracion', detalle: 'Flora 2 · 35 días en vegetativo' },
    { fecha: '2026-09-09T10:00:00Z', tipo: 'pesaje', titulo: 'Pesaje de manicura · 612 g', detalle: '18 plantas' },
  ],
  siguio_en: [{ stock_id: 52, numero: 'ST-26-052', forma: 'hash', sede: 'Central', tipo: 'derivado', gramos: 30 }],
  salidas: [
    { id: 1, tipo: 'produccion', gramos: -30, fecha: '2026-09-01', detalle: null, destino: { id: 52, numero: 'ST-26-052', forma: 'hash', sede: 'Central' } },
    { id: 2, tipo: 'merma', gramos: -2, fecha: '2026-08-22', detalle: 'se cayó el frasco', destino: null },
  ],
  dispensaciones: [
    { id: 9, fecha: '2026-09-11', cantidad_g: 3, paciente: 'María Fernández', paciente_iniciales: 'M.F.', paciente_dni_last3: '412', paciente_dni: null, canal: 'mostrador Central', junto_con: ['ST-26-052'] },
  ],
  dispensaciones_omitidas: 131,
  totales: {
    plantas_origen: 18, plantas_descartadas: 0, dispensaciones_count: 132, gramos_producidos: 612,
    gramos_dispensados: 482.5, cantidad_disponible_g: 97.5, en_mesa_g: 40, en_deposito_g: 57.5,
    otras_salidas_g: 32, entradas_g: 0, merma_g: 2, sin_explicar_g: 0, pct_dispensado: 78.8,
  },
  frase: 'Entraron 612 g de 18 plantas del lote L-26-031. 482,5 g fueron a 132 entregas. 30 g se convirtieron en ST-26-052. 2 g son merma. Quedan 97,5 g. La cuenta cierra.',
}

describe('Trazabilidad — la pantalla dibuja lo que el backend manda', () => {
  let wrapper

  beforeEach(async () => {
    vi.clearAllMocks()
    listStocks.mockResolvedValue({ data: [{ id: 41, numero_lote_producto: 'ST-26-041', forma_producto: 'flor_seca' }] })
    getStockTrazabilidad.mockResolvedValue({ data: PAYLOAD })
    const { default: Vista } = await import('../views/auditor/TrazabilidadView.vue')
    wrapper = mount(Vista, { global: { stubs: { RouterLink: true } } })
    await flushPromises()
    await wrapper.find('.trz__tr').trigger('click')
    await flushPromises()
  })

  it('la cuenta nombra cada salida y dice dónde está lo que queda', () => {
    const bal = wrapper.find('.trz__balance').text()
    expect(bal).toContain('a derivado → ST-26-052')
    expect(bal).toContain('merma · se cayó el frasco')
    expect(bal).toContain('sobre la mesa')
    expect(bal).toContain('40 g')
    expect(wrapper.find('.trz__bal-item--alerta').exists()).toBe(false) // sin_explicar_g = 0
    expect(wrapper.find('.trz__frase').text()).toContain('La cuenta cierra.')
  })

  it('la cronología se dibuja desde `cronologia`, con estados traducidos', () => {
    const items = wrapper.findAll('.trz__tl-item').map(i => i.text())
    expect(items).toHaveLength(3)
    expect(items[0]).toContain('Vegetativo')
    expect(items[1]).toContain('Floración')
    expect(items[1]).toContain('35 días en vegetativo')
    expect(wrapper.find('.trz__estado-pill').text()).toBe('En manicura')
  })

  it('el DNI son tres dígitos, la entrega dice cómo fue, y se avisa cuántas más hay', () => {
    const fila = wrapper.find('.trz__disp-table tbody tr').text()
    expect(fila).toContain('···412')
    expect(fila).not.toContain('últimos 4')
    expect(fila).toContain('mostrador Central · con ST-26-052')
    expect(wrapper.find('.trz__td-mas').text()).toContain('131 entregas más')
  })

  it('el perfil medido va al lado del declarado, y «siguió en» lleva a la otra fila', async () => {
    const origen = wrapper.find('.trz__node--origen').text()
    expect(origen).toContain('THC 18%')
    expect(origen).toContain('THC 16.4%')
    expect(origen).toContain('Cannalab')

    await wrapper.find('.trz__node--stock .trz__link').trigger('click')
    expect(getStockTrazabilidad).toHaveBeenLastCalledWith(52)
  })

  it('el pie no lleva la marca de la plataforma', () => {
    expect(wrapper.find('.trz__footer-legal').text()).not.toContain('Cultivo Espacial')
  })
})
