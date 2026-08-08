import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createMemoryHistory } from 'vue-router'

// Los lotes cerrados existían sólo detrás del tab "Finalizados", que no se lee como un
// filtro: buscarlos en el desplegable de estados era el camino natural y ahí no estaban.
const LOTES = [
  { id: 1, codigo: 'L-26-001', estado: 'finalizado', plants_count: 10 },
  { id: 2, codigo: 'L-26-002', estado: 'vegetativo', plants_count: 5 },
  { id: 3, codigo: 'L-26-003', estado: 'curado',     plants_count: 8 },
]

vi.mock('../lib/api.js', () => ({
  exportLotesCSV: vi.fn(),
  moverLotes:     vi.fn(),
  // El store pide los lotes al montar; se los damos ya listos.
  listLotes:      vi.fn(() => Promise.resolve({ data: LOTES })),
  listSalas:      vi.fn(() => Promise.resolve({ data: [] })),
  createLote:     vi.fn(),
  updateLote:     vi.fn(),
  deleteLote:     vi.fn(),
}))

describe('LotesView — el estado Finalizado se puede filtrar', () => {
  let wrapper

  beforeEach(async () => {
    setActivePinia(createPinia())
    const pinia = createPinia()
    setActivePinia(pinia)

    const router = createRouter({
      history: createMemoryHistory(),
      routes: [{ path: '/', component: { template: '<div/>' } }],
    })
    await router.push('/')
    await router.isReady()

    const { default: LotesView } = await import('../views/LotesView.vue')
    const { useLotesStore } = await import('../stores/lotes')
    const { useSalasStore } = await import('../stores/salas')

    wrapper = mount(LotesView, {
      global: {
        plugins: [pinia, router],
        stubs: { Teleport: true, AppDatePicker: true, NuevoLoteModal: true },
      },
    })

    const lotes = useLotesStore()
    lotes.items = LOTES
    lotes.fetch = vi.fn()
    useSalasStore().items = []
    useSalasStore().fetch = vi.fn()
    await wrapper.vm.$nextTick()
  })

  const selectEstado = () => wrapper.findAll('select')[0]

  it('el desplegable ofrece "Finalizado"', () => {
    const opciones = selectEstado().findAll('option').map((o) => o.text())

    expect(opciones).toContain('Finalizado')
  })

  // Elegirlo y quedarse en el tab "Activos" habría devuelto cero resultados: peor que no
  // ofrecer la opción.
  it('elegirlo lleva al tab donde están los lotes cerrados', async () => {
    expect(wrapper.text()).not.toContain('L-26-001')

    await selectEstado().setValue('finalizado')
    await wrapper.vm.$nextTick()

    expect(wrapper.text()).toContain('L-26-001')
    expect(wrapper.text()).not.toContain('L-26-002')
  })
})
