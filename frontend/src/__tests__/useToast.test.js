import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest'

// Reset module state between tests by re-importing each time
beforeEach(() => {
  vi.useFakeTimers()
})
afterEach(() => {
  vi.useRealTimers()
})

describe('useToast', () => {
  it('success() adds a toast with type success', async () => {
    const { useToast } = await import('../composables/useToast.js')
    const t = useToast()
    t.success('Guardado correctamente')
    expect(t.toasts.length).toBeGreaterThanOrEqual(1)
    const last = t.toasts[t.toasts.length - 1]
    expect(last.type).toBe('success')
    expect(last.msg).toBe('Guardado correctamente')
  })

  it('error() adds a toast with type error', async () => {
    const { useToast } = await import('../composables/useToast.js')
    const t = useToast()
    t.error('Error crítico')
    const last = t.toasts[t.toasts.length - 1]
    expect(last.type).toBe('error')
  })

  it('info() and warning() add toasts with correct types', async () => {
    const { useToast } = await import('../composables/useToast.js')
    const t = useToast()
    t.info('Información')
    t.warning('Advertencia')
    const types = t.toasts.map(x => x.type)
    expect(types).toContain('info')
    expect(types).toContain('warning')
  })

  it('remove() deletes toast by id', async () => {
    const { useToast } = await import('../composables/useToast.js')
    const t = useToast()
    t.success('Test remove')
    const id = t.toasts[t.toasts.length - 1].id
    const beforeCount = t.toasts.length
    t.remove(id)
    expect(t.toasts.length).toBe(beforeCount - 1)
    expect(t.toasts.find(x => x.id === id)).toBeUndefined()
  })

  it('toast auto-removes after timeout', async () => {
    const { useToast } = await import('../composables/useToast.js')
    const t = useToast()
    t.success('Auto-remove', { timeout: 1000 })
    const id = t.toasts[t.toasts.length - 1].id
    vi.advanceTimersByTime(1100)
    expect(t.toasts.find(x => x.id === id)).toBeUndefined()
  })
})
