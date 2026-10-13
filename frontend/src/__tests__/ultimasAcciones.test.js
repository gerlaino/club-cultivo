import { describe, it, expect, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// AC (Germán, 12-oct-2026): el inicio del autocultivo muestra las últimas acciones —qué, dónde,
// cuándo— y cada una lleva a su ficha; en el teléfono, a la ficha del teléfono.
const getUltimasAcciones = vi.fn()
vi.mock('../lib/api.js', () => ({ getUltimasAcciones: (...a) => getUltimasAcciones(...a) }))
vi.mock('../composables/useRecargaEnCambios.js', () => ({ useRecargaEnCambios: vi.fn() }))
const { default: UltimasAcciones } = await import('../components/personal/UltimasAcciones.vue')

const ACCIONES = [
  { tipo: 'planta', fecha: new Date().toISOString(), titulo: 'Trasplante', donde: 'P1', detalle: 'A 3 L', ruta: '/plantas/7' },
  { tipo: 'registro', fecha: new Date().toISOString(), titulo: 'Riego y Nutrición', donde: 'P1, P2', detalle: 'Flora 1 · 10 L: Big Bloom 20 ml', ruta: '/salas/3' },
]
const RouterLink = { props: ['to'], template: '<a :href="to"><slot /></a>' }

async function montar(props = {}) {
  getUltimasAcciones.mockResolvedValue({ data: { acciones: ACCIONES } })
  const w = mount(UltimasAcciones, { props, global: { stubs: { RouterLink } } })
  await flushPromises()
  return w
}

describe('Últimas acciones', () => {
  it('qué, dónde y lo aplicado', async () => {
    const w = await montar()
    const items = w.findAll('.ua__item')
    expect(items[1].text()).toContain('Riego y Nutrición')
    expect(items[1].text()).toContain('P1, P2')
    expect(items[1].text()).toContain('Flora 1 · 10 L: Big Bloom 20 ml')
  })

  it('en la compu lleva a la ficha de siempre', async () => {
    const w = await montar()
    expect(w.findAll('a').map(a => a.attributes('href'))).toEqual(['/plantas/7', '/salas/3'])
  })

  it('en el teléfono lleva a la ficha del teléfono', async () => {
    const w = await montar({ movil: true })
    expect(w.findAll('a').map(a => a.attributes('href'))).toEqual(['/m/planta/7', '/m/sala-m/3'])
  })
})
