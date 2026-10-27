import { describe, it, expect, vi } from 'vitest'
import { mount, shallowMount, flushPromises } from '@vue/test-utils'

// AC (Germán, 26-oct-2026): las simulaciones de cómo se usa (las grabaciones de la app) están en UN
// solo lugar, la vista «Demo» de cada puerta; cada página lleva ahí con «Ver la demo» (la portada no).
// La planta que crece por fase no es una grabación: se queda en la página de autocultivo.
window.scrollTo = () => {}
vi.mock('../lib/api.js', () => ({ getRegistroInfo: () => Promise.resolve({ data: { dias_prueba: 30, precios: null } }) }))
vi.mock('../lib/fuentesHerbario.js', () => ({ cargarFuentesHerbario: () => {} }))
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: {}, hash: '' }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}))

const destino = (to) => (typeof to === 'string' ? to : to.path + (to.hash || ''))
const RouterLink = { props: ['to'], template: '<a :data-to="destino(to)"><slot /></a>', methods: { destino } }

const montarPagina = async (archivo) => {
  const { default: V } = await import(`../views/${archivo}.vue`)
  const w = shallowMount(V, { global: { stubs: { RouterLink, PaginaPublica: { template: '<div><slot /></div>' } } } })
  await flushPromises()
  return w
}
const links = (w) => w.findAll('a').map((a) => a.attributes('data-to'))

describe('Las grabaciones viven sólo en la demo', () => {
  it('la página de organizaciones no las reproduce: lleva a su demo', async () => {
    const w = await montarPagina('LandingOrganizacionesView')
    expect(w.findComponent({ name: 'ComoSeHace' }).exists()).toBe(false)
    expect(links(w)).toContain('/bienvenida/organizaciones/demo')
    // Un solo «Ver la demo», arriba: la franja con cuadros salió (Germán: «con ese alcanza»).
    expect(links(w).filter((l) => l === '/bienvenida/organizaciones/demo')).toHaveLength(1)
  })

  it('la de autocultivo tampoco, pero la planta que crece por fase se queda', async () => {
    const w = await montarPagina('LandingAutocultivoView')
    expect(w.findComponent({ name: 'ComoSeHace' }).exists()).toBe(false)
    expect(w.findComponent({ name: 'RecorridoFases' }).exists()).toBe(true)
    expect(links(w)).toContain('/bienvenida/autocultivo/demo')
    expect(links(w).filter((l) => l === '/bienvenida/autocultivo/demo')).toHaveLength(1)
  })

  // Germán (27-oct): «Ver la demo» queda dentro de organizaciones y de autocultivo, no en la portada.
  it('la portada no lleva a la demo: se llega desde la página de cada lado', async () => {
    const w = await montarPagina('LandingView')
    expect(links(w).some((l) => l.endsWith('/demo'))).toBe(false)
    expect(links(w)).toEqual(expect.arrayContaining(['/bienvenida/organizaciones', '/bienvenida/autocultivo']))
  })
})

describe('La vista de demo', () => {
  const montarDemo = async (lado) => {
    const { default: V } = await import('../views/DemoView.vue')
    return mount(V, { props: { lado }, global: { stubs: { RouterLink, PaginaPublica: { props: ['tono', 'accion'], template: '<div :data-tono="tono"><slot /></div>' }, ComoSeHace: { name: 'ComoSeHace', props: ['flujos', 'encabezado', 'titulo'], template: '<section />' } } } })
  }

  it('organizaciones: las cuatro tareas, en verde, y cierra en el contacto', async () => {
    const w = await montarDemo('organizaciones')
    const cs = w.findComponent({ name: 'ComoSeHace' })
    expect(cs.props('flujos').map((f) => f.etiqueta)).toEqual(['Una genética nueva', 'Un lote', 'Un paciente', 'Una dispensa'])
    expect(cs.props('encabezado')).toBe('h1')
    expect(w.find('[data-tono]').attributes('data-tono')).toBe('verde')
    expect(links(w)).toContain('/bienvenida/organizaciones#contacto')
  })

  it('autocultivo: los tres pasos del teléfono, en trigo, y cierra en la cuenta gratis', async () => {
    const w = await montarDemo('autocultivo')
    const flujos = w.findComponent({ name: 'ComoSeHace' }).props('flujos')
    expect(flujos).toHaveLength(3)
    expect(flujos.every((f) => f.ids.telefono && !f.ids.compu)).toBe(true)
    expect(w.find('[data-tono]').attributes('data-tono')).toBe('trigo')
    expect(links(w)).toContain('/registro')
  })

  it('cada grabación que nombra la demo existe en public/demos (si no, el reproductor queda en negro)', async () => {
    const { FLUJOS_ORGANIZACIONES, FLUJOS_AUTOCULTIVO } = await import('../components/public/contenido.js')
    const { default: TIEMPOS } = await import('../components/public/demos/tiempos.json')
    const ids = [...FLUJOS_ORGANIZACIONES, ...FLUJOS_AUTOCULTIVO].flatMap((f) => Object.values(f.ids))
    for (const id of ids) expect(TIEMPOS[id], `falta ${id} en tiempos.json`).toBeTruthy()
  })
})

describe('Las rutas de la demo', () => {
  it('son públicas y le dicen a la vista qué lado mostrar', async () => {
    const { readFileSync } = await import('node:fs')
    const { resolve, dirname } = await import('node:path')
    const { fileURLToPath } = await import('node:url')
    const fuente = readFileSync(resolve(dirname(fileURLToPath(import.meta.url)), '../router/index.js'), 'utf8')
    for (const lado of ['organizaciones', 'autocultivo']) {
      const bloque = fuente.slice(fuente.indexOf(`path: "/bienvenida/${lado}/demo"`), fuente.indexOf(`path: "/bienvenida/${lado}/demo"`) + 300)
      expect(bloque).toContain('DemoView.vue')
      expect(bloque).toContain(`props: { lado: '${lado}' }`)
      expect(bloque).toContain('public: true')
    }
  })
})
