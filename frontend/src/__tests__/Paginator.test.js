import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import Paginator from '../components/ui/Paginator.vue'

function mkWrapper(props = {}) {
  return mount(Paginator, {
    props: { page: 1, perPage: 10, total: 50, ...props },
  })
}

describe('Paginator', () => {
  it('renders when total > perPage', () => {
    const w = mkWrapper()
    expect(w.find('.paginator').exists()).toBe(true)
  })

  it('does not render when total <= perPage and single page size', () => {
    const w = mkWrapper({ total: 5, perPage: 10, pageSizes: [10] })
    expect(w.find('.paginator').exists()).toBe(false)
  })

  it('shows correct from-to info', () => {
    const w = mkWrapper({ page: 2, perPage: 10, total: 35 })
    expect(w.text()).toContain('11–20')
    expect(w.text()).toContain('35')
  })

  it('emits update:page when next is clicked', async () => {
    const w = mkWrapper({ page: 1 })
    const btns = w.findAll('button[aria-label]')
    const next = btns.find(b => b.attributes('aria-label') === 'Página siguiente')
    await next.trigger('click')
    expect(w.emitted('update:page')).toBeTruthy()
    expect(w.emitted('update:page')[0]).toEqual([2])
  })

  it('prev button disabled on page 1', () => {
    const w = mkWrapper({ page: 1 })
    const prev = w.find('button[aria-label="Página anterior"]')
    expect(prev.attributes('disabled')).toBeDefined()
  })

  it('emits update:perPage when selector changes', async () => {
    const w = mkWrapper()
    const select = w.find('select')
    await select.setValue('25')
    expect(w.emitted('update:perPage')).toBeTruthy()
  })

  it('marks current page button as active', () => {
    const w = mkWrapper({ page: 2, total: 100 })
    const active = w.find('.paginator__btn--active')
    expect(active.text()).toBe('2')
  })
})
