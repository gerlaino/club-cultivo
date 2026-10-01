import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 30-sep-2026): «cuando registrás el riego del lote, elegir qué planta del lote fue
// regada, como con la cosecha o el pesaje de la manicura; así podés registrar riego en ciertas
// plantas 1 pulso, en ciertas otras 2». Tandas en litros o en pulsos (con «1 pulso = X L», que
// el lote recuerda). Sólo plantas en pie; cada planta en una sola tanda; el total es la suma.
const registrarLecturaOffline = vi.fn()
vi.mock('../lib/offlineApi.js', () => ({ registrarLecturaOffline: (...a) => registrarLecturaOffline(...a) }))
vi.mock('../lib/api', () => ({ registrarTrasplante: vi.fn(), createRegistroAmbiental: vi.fn() }))
vi.mock('../lib/api.js', () => ({ listRecetas: vi.fn().mockResolvedValue({ data: [] }), listInsumos: vi.fn().mockResolvedValue({ data: [] }) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }) }))

const PLANTAS = [
  { id: 11, nombre: 'P-01', state: 'vegetativo' },
  { id: 12, nombre: 'P-02', state: 'vegetativo' },
  { id: 13, nombre: 'P-03', state: 'vegetativo' },
  { id: 14, nombre: 'P-04', state: 'descartada' },
]
const LOTE = { id: 5, codigo: 'L-26-001', estado: 'vegetativo', plants_count: 3, litros_por_pulso: 0.25, plants: PLANTAS }

async function montar(lote = LOTE) {
  setActivePinia(createPinia())
  const M = (await import('../components/lotes/registro/RegistroLoteModal.vue')).default
  const w = mount(M, { props: { modelValue: true, lote, accionInicial: 'riego' },
    global: { stubs: { teleport: true, AsistenteVoz: true, DsSpinner: true, VoiceInput: true }, directives: { modal: {} } } })
  await flushPromises()
  return w
}
const boton = (w, texto) => w.findAll('button').find(b => b.text() === texto)
const guardar = async (w) => { await w.findAll('button').find(b => /Guardar/.test(b.text())).trigger('click'); await flushPromises() }
const chips = (w, tanda) => w.findAll('.rpp__tanda')[tanda].findAll('.rpp__planta')
async function elegir(w, tanda, nombres) {
  for (const n of nombres) await chips(w, tanda).find(c => c.text() === n).find('input').trigger('change')
}

describe('Riego por planta, desde el riego del lote', () => {
  beforeEach(() => { registrarLecturaOffline.mockReset().mockResolvedValue({ data: {} }) })

  it('por defecto es todo el lote y no viajan plantas', async () => {
    const w = await montar()
    await w.find('input[placeholder="20"]').setValue(6)
    await guardar(w)
    const { payload } = registrarLecturaOffline.mock.calls[0][0]
    expect(payload.plantas).toBeUndefined()
    expect(payload.volumen_l).toBe(6)
  })

  it('ofrece sólo las plantas en pie', async () => {
    const w = await montar()
    await boton(w, 'Por plantas').trigger('click')
    expect(chips(w, 0).map(c => c.text())).toEqual(['P-01', 'P-02', 'P-03'])
  })

  it('unas 1 pulso y otra 2: cada tanda viaja con sus plantas, y el pulso recordado del lote', async () => {
    const w = await montar()
    await boton(w, 'Por plantas').trigger('click')
    await elegir(w, 0, ['P-01', 'P-02'])
    await w.findAll('.rpp__tanda')[0].find('.rpp__input').setValue(1)
    await boton(w, '+ Otra tanda').trigger('click')
    // Una planta de la tanda 1 no se ofrece en la 2.
    expect(chips(w, 1).map(c => c.text())).toEqual(['P-03'])
    await elegir(w, 1, ['P-03'])
    await w.findAll('.rpp__tanda')[1].find('.rpp__input').setValue(2)
    expect(w.find('#rpp-lpp').element.value).toBe('0.25')
    expect(w.find('.rpp__total').text()).toContain('1 L en total')
    await guardar(w)
    const { payload } = registrarLecturaOffline.mock.calls[0][0]
    expect(payload.plantas).toEqual([
      { plant_ids: [11, 12], pulsos: 1, litros_por_pulso: 0.25 },
      { plant_ids: [13], pulsos: 2, litros_por_pulso: 0.25 },
    ])
    expect(payload.volumen_l).toBe(1)
  })

  it('en litros', async () => {
    const w = await montar()
    await boton(w, 'Por plantas').trigger('click')
    await elegir(w, 0, ['P-02'])
    await boton(w, 'L').trigger('click')
    await w.findAll('.rpp__tanda')[0].find('.rpp__input').setValue(1.5)
    await guardar(w)
    expect(registrarLecturaOffline.mock.calls[0][0].payload.plantas).toEqual([{ plant_ids: [12], litros: 1.5 }])
  })

  it('sin plantas elegidas no se manda y dice por qué', async () => {
    const w = await montar()
    await boton(w, 'Por plantas').trigger('click')
    await guardar(w)
    expect(registrarLecturaOffline).not.toHaveBeenCalled()
    expect(w.text()).toContain('Elegí al menos una planta regada')
  })

  it('en pulsos sin saber cuánto es un pulso no se manda', async () => {
    const w = await montar({ ...LOTE, litros_por_pulso: null })
    await boton(w, 'Por plantas').trigger('click')
    await elegir(w, 0, ['P-01'])
    await w.findAll('.rpp__tanda')[0].find('.rpp__input').setValue(1)
    await guardar(w)
    expect(registrarLecturaOffline).not.toHaveBeenCalled()
    expect(w.text()).toContain('Decí cuántos litros es un pulso')
  })
})
