import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

// CAMBIAR UN FILTRO VUELVE A LA PÁGINA 1; CAMBIAR DE PÁGINA NO.
//
// `setFiltro("page", 2)` ponía el 2 y en la línea siguiente lo pisaba con 1: el libro diario NO
// AVANZABA NUNCA. Los botones de paginado recargaban la primera página y la pantalla se quedaba
// igual, que se lee como que están rotos. Lo reportó el socio de Germán: "NO avanza de pagina".

const listMovimientos = vi.fn(() => Promise.resolve({ data: {
  movimientos: [], totales: { ingresos: 0, egresos: 0, balance: 0, count: 0 },
  pagination: { page: 1, per_page: 10, total: 30, total_pages: 3 },
} }))

vi.mock('../lib/api.js', () => ({
  getContableDashboard: vi.fn(() => Promise.resolve({ data: {} })),
  listMovimientos: (...a) => listMovimientos(...a),
  createMovimiento: vi.fn(), updateMovimiento: vi.fn(), deleteMovimiento: vi.fn(),
  exportMovimientosCSV: vi.fn(), exportMovimientosXLSX: vi.fn(),
}))

let store
beforeEach(async () => {
  setActivePinia(createPinia())
  listMovimientos.mockClear()
  const { useContabilidadStore } = await import('../stores/contabilidad')
  store = useContabilidadStore()
})

describe('Libro diario — paginación y búsqueda', () => {
  it('pedir la página 2 pide la página 2', async () => {
    store.setFiltro('page', 2)
    expect(store.filtros.page).toBe(2)

    await store.fetch()
    expect(listMovimientos.mock.calls[0][0].page).toBe(2)
  })

  it('cambiar un filtro sí vuelve a la primera página', () => {
    store.setFiltro('page', 3)
    store.setFiltro('tipo', 'egreso')
    expect(store.filtros.page).toBe(1)
  })

  it('la búsqueda viaja al servidor, que es donde está el libro entero', async () => {
    store.setFiltro('q', 'calentador')
    await store.fetch()
    expect(listMovimientos.mock.calls[0][0].q).toBe('calentador')
  })

  it('buscar arranca de nuevo en la página 1: los resultados son otra lista', () => {
    store.setFiltro('page', 3)
    store.setFiltro('q', 'calentador')
    expect(store.filtros.page).toBe(1)
  })

  it('limpiar deja la búsqueda vacía', () => {
    store.setFiltro('q', 'calentador')
    store.resetFiltros()
    expect(store.filtros.q).toBe('')
  })
})
