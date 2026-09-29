import { describe, it, expect, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 29-sep-2026): «nunca se riega una sola planta, siempre todas o gran parte del lote».
// El riego desde la ficha de una planta es del LOTE: el registro de la planta no ofrece receta ni
// productos (guardaba sólo un texto); ofrece regar el lote, que descuenta y suma como cualquier riego.
vi.mock('../lib/api', () => ({ createPlantActivity: vi.fn(), updatePlant: vi.fn() }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))

const PLANTA = { id: 1, codigo_qr: 'P-1', lote: { id: 5, codigo: 'L-26-001', estado: 'vegetativo', en_cama: false } }

async function montar(planta = PLANTA) {
  setActivePinia(createPinia())
  const M = (await import('../components/plants/RegistroPlantaModal.vue')).default
  const w = mount(M, { props: { modelValue: true, planta },
    global: { stubs: { teleport: true, AsistenteVoz: true, DsSpinner: true }, directives: { modal: {} } } })
  await flushPromises()
  return w
}

describe('Riego desde una planta', () => {
  it('no es una acción de la planta: no hay receta ni productos acá', async () => {
    const w = await montar()
    const acciones = w.findAll('.rps__accion-label').map(a => a.text())
    expect(acciones).not.toContain('Riego')
    expect(w.findComponent({ name: 'RiegoForm' }).exists()).toBe(false)
  })

  it('ofrece regar el lote, y al tocarlo cierra y pide abrir el riego del lote', async () => {
    const w = await montar()
    const b = w.find('.rps__riego-lote')
    expect(b.text()).toContain('todo el lote L-26-001')
    await b.trigger('click')
    expect(w.emitted('update:modelValue')?.at(-1)).toEqual([false])
    expect(w.emitted('regar-lote')).toHaveLength(1)
  })

  it('con el lote ya cosechado no ofrece regar', async () => {
    const w = await montar({ ...PLANTA, lote: { ...PLANTA.lote, estado: 'curado' } })
    expect(w.find('.rps__riego-lote').exists()).toBe(false)
  })
})
