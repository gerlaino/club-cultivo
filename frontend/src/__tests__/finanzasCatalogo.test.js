import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '..')

const CATEGORIAS = [
  {
    id: 1, nombre: 'Insumos', tipo: 'egreso', unidad_negocio_id: 7, es_sistema: true, activa: true,
    subcategorias: [
      { id: 11, nombre: 'Fertilizante', tipo: 'egreso', es_sistema: true, activa: true },
      { id: 12, nombre: 'Macetas',      tipo: 'egreso', es_sistema: true, activa: true },
    ],
  },
  { id: 2, nombre: 'Venta de flor', tipo: 'ingreso', unidad_negocio_id: 7, es_sistema: true, activa: true, subcategorias: [] },
  // La única que creó el club: es la excepción, y es la que lleva marca.
  { id: 3, nombre: 'Mi categoría', tipo: 'egreso', unidad_negocio_id: 7, es_sistema: false, activa: true, subcategorias: [] },
]

vi.mock('../lib/api.js', () => ({
  listDepositos: vi.fn(() => Promise.resolve({ data: [{ id: 1, nombre: 'Depósito Cultivo', unidad_negocio_id: 7, sede_nombre: 'Central' }] })),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn(() => Promise.resolve(true)) }) }))

vi.mock('../stores/catalogoFinanzas.js', () => ({
  useCatalogoFinanzasStore: () => ({
    loading: false, saving: false, saveError: null,
    categorias: CATEGORIAS,
    unidades: [{ id: 7, nombre: 'Cultivo', color: '#15803d', es_sistema: true, activa: true }],
    unidadesActivas: [{ id: 7, nombre: 'Cultivo' }],
    fetchAll: vi.fn(() => Promise.resolve()),
    actualizarCategoria: vi.fn(), crearCategoria: vi.fn(), eliminarCategoria: vi.fn(),
    actualizarUnidad: vi.fn(), crearUnidad: vi.fn(), eliminarUnidad: vi.fn(),
  }),
}))

describe('Contabilidad → Categorías', () => {
  let wrapper

  async function montar() {
    setActivePinia(createPinia())
    const { default: Vista } = await import('../views/admin/FinanzasCatalogoView.vue')
    const w = mount(Vista, { global: { stubs: { Teleport: true } } })
    for (let i = 0; i < 5; i++) await new Promise((r) => setTimeout(r, 0))
    // El sector arranca plegado: se despliega para ver su contenido.
    await w.find('.acc-head').trigger('click')
    return w
  }

  beforeEach(async () => { wrapper = await montar() })

  // El error que ya cometí una vez: escribir markup con clases que no existen en el <style>.
  it('ninguna clase del template quedó sin estilo', () => {
    for (const rel of ['views/admin/FinanzasCatalogoView.vue', 'components/contabilidad/CategoriaFila.vue']) {
      const src = readFileSync(resolve(raiz, rel), 'utf8')
      const markup = src.replace(/<script[\s\S]*?<\/script>/g, '').replace(/<style[\s\S]*?<\/style>/g, '')
      const definidas = new Set([...src.slice(src.indexOf('<style')).matchAll(/\.([a-zA-Z0-9_-]+)/g)].map((m) => m[1]))
      const usadas = new Set()
      // (?<!:) — `:class` lleva expresiones, no nombres de clase literales.
      for (const m of markup.matchAll(/(?<!:)\bclass="([^"]*)"/g)) {
        for (const c of m[1].split(/\s+/)) if (c && !c.startsWith('bi')) usadas.add(c)
      }
      expect([...usadas].filter((c) => !definidas.has(c)), rel).toEqual([])
    }
  })

  it('el manual de cuatro líneas ya no ocupa la pantalla', () => {
    expect(wrapper.text()).not.toContain('El club por sectores')
    expect(wrapper.find('.cat-ayuda').exists()).toBe(false)
  })

  it('la ayuda sigue estando, a pedido', async () => {
    await wrapper.find('.cat-ayuda-btn').trigger('click')

    expect(wrapper.find('.cat-ayuda').exists()).toBe(true)
    expect(wrapper.find('.cat-ayuda').text()).toContain('sector')
  })

  it('egresos e ingresos van en dos columnas', () => {
    const cols = wrapper.findAll('.cat-col__head').map((c) => c.text())

    expect(cols).toEqual(['Egresos', 'Ingresos'])
  })

  it('marca lo PROPIO, y no repite "sistema" en cada fila', () => {
    const texto = wrapper.text()

    expect(texto).toContain('propia')
    expect(texto.toLowerCase()).not.toContain('sistema')
  })

  it('las acciones no gritan: viven en el menú de cada fila', async () => {
    // En reposo no hay veinte "Editar/Desactivar" compitiendo con los nombres.
    expect(wrapper.text()).not.toContain('Desactivar')

    await wrapper.findAll('.cf__mas')[0].trigger('click')

    const menu = wrapper.find('.cf__menu')
    expect(menu.text()).toContain('Editar')
    expect(menu.text()).toContain('Desactivar')
    expect(menu.text()).toContain('Agregar subcategoría')
  })

  it('una categoría del sistema no ofrece eliminar; una propia sí', async () => {
    await wrapper.findAll('.cf__mas')[0].trigger('click')   // Insumos, del sistema
    expect(wrapper.find('.cf__menu').text()).not.toContain('Eliminar')
  })

  it('muestra la subcategoría debajo de su madre', () => {
    const nombres = wrapper.findAll('.cf__nombre').map((n) => n.text())

    expect(nombres.slice(0, 3)).toEqual(['Insumos', 'Fertilizante', 'Macetas'])
  })

  it('los depósitos son una línea al pie, no una sección aparte', () => {
    expect(wrapper.find('.cat-deps').text()).toContain('Depósito Cultivo')
  })

  it('el plural roto de "Sectors" ya no está', () => {
    expect(wrapper.text()).toContain('Sectores de la organización')
    expect(wrapper.text()).not.toContain('Sectors')
  })
})
