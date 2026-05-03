import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import EmptyState from '../components/ui/EmptyState.vue'

describe('EmptyState', () => {
  it('renders title and message', () => {
    const w = mount(EmptyState, { props: { title: 'Sin datos', message: 'No hay nada aquí' } })
    expect(w.text()).toContain('Sin datos')
    expect(w.text()).toContain('No hay nada aquí')
  })

  it('renders emoji icon as span', () => {
    const w = mount(EmptyState, { props: { title: 'T', icon: '🌿' } })
    expect(w.find('span.empty-state__icon').text()).toBe('🌿')
  })

  it('renders bootstrap icon as <i>', () => {
    const w = mount(EmptyState, { props: { title: 'T', icon: 'bi-search' } })
    const el = w.find('i.bi.bi-search')
    expect(el.exists()).toBe(true)
  })

  it('applies compact class when compact=true', () => {
    const w = mount(EmptyState, { props: { title: 'T', compact: true } })
    expect(w.find('.empty-state').classes()).toContain('empty-state--compact')
  })

  it('renders #actions slot', () => {
    const w = mount(EmptyState, {
      props: { title: 'T' },
      slots: { actions: '<button id="cta">Crear</button>' },
    })
    expect(w.find('#cta').exists()).toBe(true)
  })

  it('does not render message element when message is empty', () => {
    const w = mount(EmptyState, { props: { title: 'T' } })
    expect(w.find('.empty-state__msg').exists()).toBe(false)
  })
})
