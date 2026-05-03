import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { mount } from '@vue/test-utils'
import ConfirmDialog from '../components/ui/ConfirmDialog.vue'
import { useConfirm } from '../composables/useConfirm.js'

beforeEach(() => {
  const { cancel } = useConfirm()
  cancel()
})

afterEach(() => {
  document.querySelectorAll('.cd-overlay').forEach(el => el.remove())
})

describe('ConfirmDialog', () => {
  it('is hidden when state.open is false', () => {
    const w = mount(ConfirmDialog, { attachTo: document.body })
    expect(document.querySelector('.cd-overlay')).toBeNull()
    w.unmount()
  })

  it('shows title and message from confirm()', async () => {
    const w = mount(ConfirmDialog, { attachTo: document.body })
    const { confirm } = useConfirm()
    confirm({ title: 'Confirmar borrado', message: '¿Seguro?' })
    await w.vm.$nextTick()
    expect(document.querySelector('.cd-title')?.textContent).toBe('Confirmar borrado')
    expect(document.querySelector('.cd-msg')?.textContent).toBe('¿Seguro?')
    w.unmount()
  })

  it('resolves true when accept button clicked', async () => {
    const w = mount(ConfirmDialog, { attachTo: document.body })
    const { confirm } = useConfirm()
    const promise = confirm({ title: 'Test' })
    await w.vm.$nextTick()
    document.querySelector('.btn-danger')?.click()
    expect(await promise).toBe(true)
    w.unmount()
  })

  it('resolves false when cancel button clicked', async () => {
    const w = mount(ConfirmDialog, { attachTo: document.body })
    const { confirm } = useConfirm()
    const promise = confirm({ title: 'Test' })
    await w.vm.$nextTick()
    document.querySelector('.btn-outline-secondary')?.click()
    expect(await promise).toBe(false)
    w.unmount()
  })

  it('resolves false on Escape key', async () => {
    const w = mount(ConfirmDialog, { attachTo: document.body })
    const { confirm } = useConfirm()
    const promise = confirm({ title: 'Test' })
    await w.vm.$nextTick()
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    expect(await promise).toBe(false)
    w.unmount()
  })

  it('uses variant btn class for confirm button', async () => {
    const w = mount(ConfirmDialog, { attachTo: document.body })
    const { confirm } = useConfirm()
    confirm({ title: 'T', variant: 'warning' })
    await w.vm.$nextTick()
    expect(document.querySelector('.btn-warning')).not.toBeNull()
    w.unmount()
  })
})
