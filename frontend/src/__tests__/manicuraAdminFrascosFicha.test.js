import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 30-oct-2026): «el admin, al momento de registrar el pesaje, tiene que poder dividir
// esa planta en uno o más frascos, existentes o nuevos». Es el «Registrar pesaje» de la ficha del
// lote: el admin (y el supervisor) elige un frasco nuevo, uno del lote, o reparte en varios; la
// manicura sigue mandando su pesaje a confirmar, sin elegir frasco.

const api = {
  createPesajeManicura: vi.fn(() => Promise.resolve({ data: {} })),
  registrarDirectoManicura: vi.fn(() => Promise.resolve({ data: {} })),
  listPlants: vi.fn(), listStocks: vi.fn(), listSedes: vi.fn(),
}
vi.mock('../lib/api.js', () => api)
vi.mock('../lib/api', () => api)
const registrarConJornada = vi.fn((_lote, fn) => fn({}))
vi.mock('../composables/useManicuraJornada', () => ({ useManicuraJornada: () => ({ registrarConJornada }) }))

const LOTE = { id: 5, codigo: 'L-26-010', estado: 'en_manicura', manicurador_id: 1 }
const PLANTA = { id: 1, nombre: 'P1', state: 'secado', peso_seco: null, tiene_pesada: false }
const FRASCOS = [
  { id: 70, forma_producto: 'flor_seca', estado: 'asignado', cantidad: 12, numero_lote_producto: 'ST-70', descripcion: 'Copones' },
  { id: 71, forma_producto: 'flor_seca', estado: 'agotado',  cantidad: 0,  numero_lote_producto: 'ST-71' },
  { id: 72, forma_producto: 'esqueje',   estado: 'asignado', cantidad: 4,  numero_lote_producto: 'ST-72' },
]
const CALIDADES = { altos: 'Altos', medios: 'Medios', bajos: 'Bajos', otro: 'Otro' }

beforeEach(() => {
  vi.clearAllMocks(); setActivePinia(createPinia())
  api.listPlants.mockResolvedValue({ data: [PLANTA] })
  api.listStocks.mockResolvedValue({ data: FRASCOS })
  api.listSedes.mockResolvedValue({ data: [{ id: 3, nombre: 'Centro' }] })
})

async function montar(role, { calidadObligatoria = true } = {}) {
  const { useAuthStore } = await import('../stores/auth')
  useAuthStore().user = { id: 1, role, reglas_stock: { calidades: CALIDADES, calidad_obligatoria: calidadObligatoria } }
  const { default: M } = await import('../components/lotes/CompletarManicuraModal.vue')
  const w = mount(M, { props: { modelValue: false, lote: LOTE },
    global: { stubs: { Teleport: true, DsSpinner: true }, directives: { modal: {} } } })
  await w.setProps({ modelValue: true }); await flushPromises()
  await w.find('input[type="number"]').setValue(30)
  return w
}
const enviar = w => w.find('.cmm__btn-primary')
const fila = (w, i) => w.findAll('.rpf__fila')[i]
const linkRepartir = w => w.findAll('.cmm__link').find(b => b.text().includes('Repartir'))

describe('Registrar pesaje desde la ficha del lote: a qué frasco va', () => {
  it('ofrece frasco nuevo y los frascos de flor seca del lote, también los vacíos', async () => {
    const w = await montar('admin')
    expect(api.listStocks).toHaveBeenCalledWith({ lote_id: 5, incluir_vacios: 1 })
    const opciones = w.find('#cmm-frasco').findAll('option').map(o => o.text())
    expect(opciones[0]).toBe('Frasco nuevo')
    expect(opciones.some(t => t.includes('ST-70') && t.includes('Copones'))).toBe(true)
    expect(opciones.some(t => t.includes('ST-71') && t.includes('vacío, se vuelve a usar'))).toBe(true)
    expect(opciones.some(t => t.includes('ST-72'))).toBe(false) // no es flor seca
  })

  it('a un frasco existente: manda ese frasco y no pide calidad', async () => {
    const w = await montar('admin')
    await w.find('#cmm-frasco').setValue(70)
    expect(w.find('.cfn').exists()).toBe(false)
    await enviar(w).trigger('click'); await flushPromises()
    expect(api.registrarDirectoManicura).toHaveBeenCalledWith(5, { resto: { plant_ids: [1], peso_total_g: 30 }, stock_id: 70 })
  })

  it('a un frasco nuevo: pide la calidad antes de mandar, y manda la sede elegida', async () => {
    const w = await montar('admin')
    await enviar(w).trigger('click'); await flushPromises()
    expect(api.registrarDirectoManicura).not.toHaveBeenCalled()
    expect(w.find('.cmm__alert').text()).toContain('calidad')
    await w.find('.cfn select').setValue('medios')
    await w.find('#cmm-sede').setValue(3)
    await enviar(w).trigger('click'); await flushPromises()
    expect(api.registrarDirectoManicura).toHaveBeenCalledWith(5, { resto: { plant_ids: [1], peso_total_g: 30 }, calidad: 'medios', sede_id: 3 })
  })

  for (const role of ['admin', 'supervisor']) {
    it(`como ${role}: reparte en un frasco existente y uno nuevo; el botón espera a que sume el peso`, async () => {
      const w = await montar(role)
      await linkRepartir(w).trigger('click')
      expect(w.findAll('.rpf__fila')).toHaveLength(2)
      await fila(w, 0).find('select').setValue(70)
      await fila(w, 0).find('.rpf__input--g').setValue(20)
      expect(enviar(w).attributes('disabled')).toBeDefined() // 20 de 30
      expect(w.find('.rpf__total').text()).toContain('faltan 10')
      await fila(w, 1).find('.rpf__input--g').setValue(10)
      expect(enviar(w).attributes('disabled')).toBeUndefined()
      expect(enviar(w).text()).toContain('Registrar en 2 frascos')
      await enviar(w).trigger('click'); await flushPromises()
      expect(api.registrarDirectoManicura).toHaveBeenCalledWith(5, {
        resto: { plant_ids: [1], peso_total_g: 30 },
        destinos: [
          { stock_id: 70, gramos: 20, descripcion: undefined, calidad: undefined },
          { stock_id: undefined, gramos: 10, descripcion: 'Bajos', calidad: 'bajos' },
        ],
      })
    })
  }

  it('repartido de más tampoco se manda', async () => {
    const w = await montar('admin')
    await linkRepartir(w).trigger('click')
    await fila(w, 0).find('.rpf__input--g').setValue(25)
    await fila(w, 1).find('.rpf__input--g').setValue(10)
    expect(w.find('.rpf__total').text()).toContain('sobran 5')
    expect(enviar(w).attributes('disabled')).toBeDefined()
  })

  it('un frasco nuevo del reparto sin calidad no se manda', async () => {
    const w = await montar('admin')
    await linkRepartir(w).trigger('click')
    await fila(w, 0).find('.rpf__select--calidad').setValue('')
    await fila(w, 0).find('.rpf__input--g').setValue(20)
    await fila(w, 1).find('.rpf__input--g').setValue(10)
    await enviar(w).trigger('click'); await flushPromises()
    expect(api.registrarDirectoManicura).not.toHaveBeenCalled()
    expect(w.find('.cmm__alert').text()).toContain('calidad')
  })

  it('«Mandar todo a un solo frasco» vuelve al frasco único', async () => {
    const w = await montar('admin')
    await linkRepartir(w).trigger('click')
    await w.findAll('.cmm__link').find(b => b.text().includes('un solo frasco')).trigger('click')
    expect(w.find('.rpf__fila').exists()).toBe(false)
    expect(w.find('#cmm-frasco').exists()).toBe(true)
  })

  it('el admin no ve «Notas»: el registro directo no las guarda', async () => {
    const w = await montar('admin')
    expect(w.find('textarea').exists()).toBe(false)
  })

  it('la manicura no elige frasco: su pesaje va a confirmar', async () => {
    const w = await montar('manicura')
    expect(w.find('textarea').exists()).toBe(true)
    expect(w.find('#cmm-frasco').exists()).toBe(false)
    expect(linkRepartir(w)).toBeUndefined()
    expect(api.listStocks).not.toHaveBeenCalled()
    expect(enviar(w).text()).toContain('Enviar a confirmar')
    await enviar(w).trigger('click'); await flushPromises()
    expect(api.createPesajeManicura).toHaveBeenCalled()
    expect(api.registrarDirectoManicura).not.toHaveBeenCalled()
  })
})
