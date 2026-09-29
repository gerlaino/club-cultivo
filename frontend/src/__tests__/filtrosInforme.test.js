import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'

// AC (Germán, 29-sep): al elegir un informe se arma a gusto —algunos lotes, algunos pacientes, sólo
// el stock externo—. La barra ofrece sólo los filtros que ese informe usa y emite los parámetros que van
// igual a la pantalla y a la descarga.
const get = vi.fn()
vi.mock('../lib/api.js', () => ({ default: { get: (...a) => get(...a) } }))

const FiltrosInforme = (await import('../components/informes/FiltrosInforme.vue')).default

const OPCIONES = {
  lotes: [{ id: 1, codigo: 'L-26-001', genetica: 'Critical' }, { id: 2, codigo: 'L-26-002', genetica: 'Kush' }],
  pacientes: [{ id: 7, nombre: 'Ana Pérez', dni_ultimos_3: '222' }],
  geneticas: [], sedes: [{ id: 3, nombre: 'Centro' }], dispensadores: [], formas: [{ valor: 'preroll', nombre: 'Preroll' }],
}
const tick = () => new Promise(r => setTimeout(r, 0))

async function montar(usa) {
  const w = mount(FiltrosInforme, { props: { usa } })
  await w.find('.fin__toggle').trigger('click'); await tick()
  return w
}
const tildar = async (w, texto) => {
  const opt = w.findAll('.fin__opt').find(o => o.text().includes(texto))
  await opt.find('input').setValue(true)
}
const aplicar = async (w) => { await w.find('.fin__btn').trigger('click'); await tick() }
const ultimo = (w) => w.emitted('change').at(-1)[0]

describe('FiltrosInforme', () => {
  beforeEach(() => { get.mockReset(); get.mockResolvedValue({ data: OPCIONES }) })

  it('ofrece sólo los filtros que el informe usa', async () => {
    const w = await montar(['lotes', 'origen'])
    const titulos = w.findAll('.fin__titulo').map(t => t.text())
    expect(titulos.some(t => t.startsWith('Lotes'))).toBe(true)
    expect(titulos.some(t => t.startsWith('Pacientes'))).toBe(false)
  })

  it('no pide el informe mientras se tilda: recién al aplicar', async () => {
    const w = await montar(['lotes'])
    await tildar(w, 'L-26-001')
    expect(w.emitted('change')).toBeUndefined()
    await aplicar(w)
    expect(ultimo(w)).toEqual({ lote_ids: [1] })
  })

  it('varios lotes y el origen, en los parámetros de la API', async () => {
    const w = await montar(['lotes', 'origen'])
    await tildar(w, 'L-26-001'); await tildar(w, 'L-26-002')
    await w.findAll('input[type=radio]').find(r => r.element.value === 'externo').setValue(true)
    await aplicar(w)
    expect(ultimo(w)).toEqual({ lote_ids: [1, 2], origen: 'externo' })
  })

  it('lo aplicado queda como chips, y sacar uno vuelve a pedir sin él', async () => {
    const w = await montar(['lotes', 'pacientes'])
    await tildar(w, 'L-26-001'); await tildar(w, 'Ana Pérez')
    await aplicar(w)
    expect(w.findAll('.fin__chip').map(c => c.text())).toEqual(['L-26-001 ×', 'Ana Pérez ×'])

    await w.findAll('.fin__chip-x')[1].trigger('click')
    expect(ultimo(w)).toEqual({ lote_ids: [1] })
  })

  it('«Limpiar» vuelve a todo', async () => {
    const w = await montar(['lotes'])
    await tildar(w, 'L-26-001'); await aplicar(w)
    await w.find('.fin__limpiar').trigger('click')
    expect(ultimo(w)).toEqual({})
  })

  it('del paciente se muestra el DNI parcial', async () => {
    const w = await montar(['pacientes'])
    expect(w.text()).toContain('DNI …222')
  })
})
