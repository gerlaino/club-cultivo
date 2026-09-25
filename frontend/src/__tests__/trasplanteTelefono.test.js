import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { metaDetalle } from '../lib/historialHelpers.js'

// AC (Germán, 24-sep-2026): el enraizado va en incubadora (hidroponía) o en jiffy, y al pasar al
// vasito de 0,335 L lo de la incubadora queda en sustrato. El trasplante del teléfono tiene que
// traer eso marcado, guardar fecha, medio, raíces y observaciones (antes los tiraba y sólo cambiaba
// la maceta) y pasar por la misma puerta que el de escritorio.
const api = vi.hoisted(() => ({ registrarTrasplante: vi.fn(() => Promise.resolve({ data: { ok: true } })) }))
vi.mock('../lib/api', () => ({
  registrarTrasplante: (...a) => api.registrarTrasplante(...a),
  createRegistroAmbiental: vi.fn(),
}))
vi.mock('../lib/offlineApi.js', () => ({ registrarLecturaOffline: vi.fn() }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))
vi.mock('../stores/club', () => ({ useClubStore: () => ({ data: null }) }))

const ENRAIZANDO = {
  id: 5, codigo: 'L-26-070', estado: 'enraizado', plants_count: 3,
  metodo_enraizado: 'incubadora', grow_type: 'hidroponia', medio_al_trasplantar: 'sustrato',
}

async function abrir(lote) {
  setActivePinia(createPinia())
  const M = (await import('../components/lotes/registro/RegistroLoteModal.vue')).default
  const w = mount(M, {
    props: { modelValue: true, lote, accionInicial: 'trasplante', plants: [{ id: 1 }, { id: 2 }, { id: 3 }] },
    global: { stubs: { teleport: true, AsistenteVoz: true }, directives: { modal: {} } },
    attachTo: document.body,
  })
  await flushPromises()
  return w
}

describe('Trasplante desde el teléfono', () => {
  beforeEach(() => api.registrarTrasplante.mockClear())

  it('de la incubadora al vasito viene marcado sustrato y dice de dónde viene', async () => {
    const w = await abrir(ENRAIZANDO)

    expect(w.find('.tf__radio-btn--sel').text()).toContain('Sustrato')
    expect(w.text()).toContain('Viene de: Incubadora (hidroponía)')
  })

  it('enraizando no ofrece elegir algunas plantas: pasan todas', async () => {
    const w = await abrir(ENRAIZANDO)

    expect(w.text()).not.toContain('Selección manual')
    expect(w.text()).toContain('Desprender')
  })

  it('guarda por la puerta del trasplante con fecha, medio, sustrato, raíces y observaciones', async () => {
    const w = await abrir(ENRAIZANDO)
    await w.find('input[placeholder="0.335"]').setValue('0.335')
    await w.findAll('input').find(i => i.attributes('placeholder')?.startsWith('Ej: turba')).setValue('turba')
    await w.findAll('.tf__radio-btn').find(b => b.text().includes('Buena')).trigger('click')
    await w.find('textarea').setValue('raíz blanca')

    await w.find('.rls__btn-save, button.rls__save, [class*="save"]').trigger('click')
    await flushPromises()

    expect(api.registrarTrasplante).toHaveBeenCalledTimes(1)
    const [id, payload] = api.registrarTrasplante.mock.calls[0]
    expect(id).toBe(5)
    expect(payload).toMatchObject({
      maceta_destino_l: 0.335, medio: 'sustrato', sustrato: 'turba',
      estado_raices: 'buena', observaciones: 'raíz blanca',
    })
    expect(payload.fecha).toMatch(/^\d{4}-\d{2}-\d{2}$/)
    expect(payload.plant_ids).toBeUndefined()
  })

  it('el historial muestra el cambio de medio y las raíces', () => {
    const t = metaDetalle({ metadata: { maceta_destino_l: 0.335, medio_origen: 'incubadora', medio_destino: 'sustrato', estado_raices: 'buena' } })
    expect(t).toContain('Incubadora (hidroponía) → Sustrato')
    expect(t).toContain('raíces: buena')
  })
})
