import { describe, it, expect, beforeEach } from 'vitest'
import { useConfirm } from '../composables/useConfirm.js'

beforeEach(() => {
  const { cancel } = useConfirm()
  cancel()
})

describe('useConfirm', () => {
  it('confirm() opens state and returns a promise', () => {
    const { confirm, state } = useConfirm()
    const p = confirm({ title: 'Test' })
    expect(state.open).toBe(true)
    expect(p).toBeInstanceOf(Promise)
  })

  it('accept() resolves the promise with true', async () => {
    const { confirm, accept } = useConfirm()
    const p = confirm({ title: 'Test' })
    accept()
    expect(await p).toBe(true)
  })

  it('cancel() resolves the promise with false', async () => {
    const { confirm, cancel } = useConfirm()
    const p = confirm({ title: 'Test' })
    cancel()
    expect(await p).toBe(false)
  })

  it('accept() closes the dialog', () => {
    const { confirm, accept, state } = useConfirm()
    confirm({})
    accept()
    expect(state.open).toBe(false)
  })

  it('cancel() closes the dialog', () => {
    const { confirm, cancel, state } = useConfirm()
    confirm({})
    cancel()
    expect(state.open).toBe(false)
  })

  it('sets default options when not provided', () => {
    const { confirm, state } = useConfirm()
    confirm({})
    expect(state.title).toBe('¿Estás seguro?')
    expect(state.variant).toBe('danger')
    expect(state.confirmText).toBe('Confirmar')
    expect(state.cancelText).toBe('Cancelar')
  })

  it('uses provided options', () => {
    const { confirm, state } = useConfirm()
    confirm({ title: 'Borrar', message: 'No reversible', variant: 'warning', confirmText: 'Sí', cancelText: 'No' })
    expect(state.title).toBe('Borrar')
    expect(state.message).toBe('No reversible')
    expect(state.variant).toBe('warning')
  })
})
