import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 30-sep-2026): en el riego de una sala con varios lotes se carga el total (y se
// reparte) o, con «Cargar por lote», lo de cada uno y el total es la suma. Sólo los lotes que
// reciben el riego de la sala (lo dice el backend: `recibe_registro_sala`). Un lote sin número
// no viaja (queda «sin volumen cargado», no 0).
const registrarSalaOffline = vi.fn()
vi.mock('../lib/offlineApi.js', () => ({ registrarSalaOffline: (...a) => registrarSalaOffline(...a) }))
vi.mock('../lib/api.js', () => ({ listRecetas: vi.fn().mockResolvedValue({ data: [] }), listInsumos: vi.fn().mockResolvedValue({ data: [] }) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }) }))

const SALA = {
  id: 7, nombre: 'Vege 1', camas: [],
  lotes: [
    { id: 1, codigo: 'L-26-001', estado: 'vegetativo', recibe_registro_sala: true },
    { id: 2, codigo: 'L-26-002', estado: 'vegetativo', recibe_registro_sala: true },
    { id: 3, codigo: 'L-26-003', estado: 'enraizado',  recibe_registro_sala: false },
  ],
}

async function montar(sala = SALA) {
  setActivePinia(createPinia())
  const M = (await import('../components/salas/RegistroSalaModal.vue')).default
  const w = mount(M, { props: { modelValue: true, sala, accionInicial: 'riego' },
    global: { stubs: { teleport: true, AsistenteVoz: true, DsSpinner: true, VoiceInput: true }, directives: { modal: {} } } })
  await flushPromises()
  return w
}
const guardar = async (w) => { await w.findAll('button').find(b => /Guardar/.test(b.text())).trigger('click'); await flushPromises() }

describe('Volumen del riego de la sala: total o por lote', () => {
  beforeEach(() => { registrarSalaOffline.mockReset().mockResolvedValue({ data: { lotes_afectados: 2 } }) })

  it('por defecto se carga el total y viaja como total', async () => {
    const w = await montar()
    expect(w.find('.rf__por-lote').exists()).toBe(false)
    await w.find('input[placeholder="20"]').setValue(40)
    await guardar(w)
    const payload = registrarSalaOffline.mock.calls[0][1]
    expect(payload.volumen_l).toBe(40)
    expect(payload.volumenes).toBeUndefined()
  })

  it('«Cargar por lote» ofrece sólo los que reciben el riego, suma el total y manda cada uno', async () => {
    const w = await montar()
    await w.findAll('.rf__link').find(b => b.text() === 'Cargar por lote').trigger('click')
    const filas = w.findAll('.rf__por-lote-fila')
    expect(filas.map(f => f.find('.rf__por-lote-codigo').text())).toEqual(['L-26-001', 'L-26-002'])
    await filas[0].find('input').setValue(25)
    await filas[1].find('input').setValue(15)
    expect(w.find('.rf__por-lote-total').text()).toContain('40')
    await guardar(w)
    const payload = registrarSalaOffline.mock.calls[0][1]
    expect(payload.volumenes).toEqual({ 1: 25, 2: 15 })
    expect(payload.volumen_l).toBe(40)
  })

  it('un lote sin número no viaja (no es 0 L)', async () => {
    const w = await montar()
    await w.findAll('.rf__link').find(b => b.text() === 'Cargar por lote').trigger('click')
    await w.findAll('.rf__por-lote-fila')[0].find('input').setValue(10)
    await guardar(w)
    expect(registrarSalaOffline.mock.calls[0][1].volumenes).toEqual({ 1: 10 })
  })

  it('con un solo lote que recibe el riego no se ofrece «por lote»', async () => {
    const w = await montar({ ...SALA, lotes: [SALA.lotes[0], SALA.lotes[2]] })
    expect(w.findAll('.rf__link').some(b => b.text() === 'Cargar por lote')).toBe(false)
  })
})
