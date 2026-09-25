import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán): en la tabla de lotes, ver ahí mismo —al pasar el mouse o abriendo la fila— los
// días de las fases ya pasadas. Y la tabla de la sala tiene que ser la misma que la de /lotes.
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }))

const LOTE = {
  id: 7, codigo: 'L-26-006', estado: 'floracion', sala_id: 3, plants_count: 10, tamanio_maceta: 3,
  start_date: '2026-06-09', dias_en_estado: 12, fecha_estado_actual: '2026-09-12',
  fases: [
    { estado: 'enraizado',  desde: '2026-06-09', hasta: '2026-06-24', dias: 15, actual: false },
    { estado: 'vegetativo', desde: '2026-06-24', hasta: '2026-09-12', dias: 80, actual: false },
    { estado: 'floracion',  desde: '2026-09-12', hasta: null,         dias: 12, actual: true },
  ],
}

async function montar(props = {}) {
  const LotesTabla = (await import('../components/lotes/LotesTabla.vue')).default
  return mount(LotesTabla, { props: { lotes: [LOTE], ...props } })
}

describe('Tabla de lotes: días por fase', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('el cartelito del mouse lista sólo las fases que ya pasaron, con sus días', async () => {
    const w = await montar()
    const pop = w.find('.lt-pop').text()

    expect(pop).toContain('Enraizado')
    expect(pop).toContain('15 d')
    expect(pop).toContain('Vegetativo')
    expect(pop).toContain('80 d')
    expect(pop).not.toContain('Floración')
  })

  it('la flechita abre la fila con cada fase y sus días; la actual dice «ahora»', async () => {
    const w = await montar()
    expect(w.find('.lt-detalle').exists()).toBe(false)

    await w.find('.lt-chev').trigger('click')

    const fases = w.findAll('.lt-fase')
    expect(fases).toHaveLength(3)
    expect(fases[0].text()).toContain('15 d')
    expect(fases[1].text()).toContain('80 d')
    expect(fases[2].text()).toContain('ahora')
  })

  it('un lote sin cambios de fase lo dice en vez de quedar en blanco', async () => {
    const w = await montar({ lotes: [{ ...LOTE, fases: [] }] })

    await w.find('.lt-chev').trigger('click')

    expect(w.find('.lt-fases-vacio').exists()).toBe(true)
    expect(w.find('.lt-pop').text()).toContain('Sin fases anteriores')
  })

  it('adentro de una sala no repite la columna Sala', async () => {
    const w = await montar({ mostrarSala: false })

    expect(w.findAll('th').map(t => t.text()).join(' ')).not.toContain('Sala')
    expect(w.find('td[data-label="Sala"]').exists()).toBe(false)
  })
})
