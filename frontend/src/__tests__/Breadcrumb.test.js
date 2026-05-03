import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createRouter, createMemoryHistory } from 'vue-router'
import Breadcrumb from '../components/ui/Breadcrumb.vue'

function mkRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', component: { template: '<div/>' } },
      { path: '/sedes', component: { template: '<div/>' } },
      { path: '/sedes/:id', component: { template: '<div/>' } },
    ],
  })
}

describe('Breadcrumb', () => {
  it('renders all item labels', () => {
    const router = mkRouter()
    const w = mount(Breadcrumb, {
      global: { plugins: [router] },
      props: {
        items: [
          { label: 'Sedes', to: '/sedes' },
          { label: 'Sede Norte', to: '/sedes/1' },
          { label: 'Sala A' },
        ],
      },
    })
    expect(w.text()).toContain('Sedes')
    expect(w.text()).toContain('Sede Norte')
    expect(w.text()).toContain('Sala A')
  })

  it('marks last item with aria-current="page"', () => {
    const router = mkRouter()
    const w = mount(Breadcrumb, {
      global: { plugins: [router] },
      props: { items: [{ label: 'Sedes', to: '/sedes' }, { label: 'Última' }] },
    })
    const current = w.find('[aria-current="page"]')
    expect(current.exists()).toBe(true)
    expect(current.text()).toBe('Última')
  })

  it('renders links for non-last items', () => {
    const router = mkRouter()
    const w = mount(Breadcrumb, {
      global: { plugins: [router] },
      props: { items: [{ label: 'Sedes', to: '/sedes' }, { label: 'Última' }] },
    })
    const links = w.findAll('a.bc__link')
    expect(links.length).toBeGreaterThanOrEqual(1)
    expect(links[0].text()).toBe('Sedes')
  })

  it('renders separators between items', () => {
    const router = mkRouter()
    const w = mount(Breadcrumb, {
      global: { plugins: [router] },
      props: { items: [{ label: 'A', to: '/' }, { label: 'B', to: '/sedes' }, { label: 'C' }] },
    })
    const seps = w.findAll('.bc__sep')
    expect(seps.length).toBe(2)
  })
})
