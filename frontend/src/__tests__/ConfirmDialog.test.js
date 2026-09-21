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

// El «¿seguro?» va ARRIBA de cualquier overlay de la app. Quedó debajo del lightbox de fotos
// (9999) y de su barra de acciones (10001): se podía tocar «Editar» con el cartel de eliminar
// abierto (Germán, 21-sep). Este test lee los z-index reales de `src` para que no vuelva a pasar.
describe('El cartel de confirmación siempre gana', () => {
  it('su z-index supera al de todo overlay que no sea la barra de carga', async () => {
    const { readFileSync, readdirSync, statSync } = await import('node:fs')
    const { resolve, dirname } = await import('node:path')
    const { fileURLToPath } = await import('node:url')
    const SRC = resolve(dirname(fileURLToPath(import.meta.url)), '..')
    const archivos = []
    const walk = (d) => readdirSync(d).forEach(n => { const p = resolve(d, n); statSync(p).isDirectory() ? walk(p) : (/\.(vue|css)$/.test(n) && archivos.push(p)) })
    walk(SRC)

    const dialog = readFileSync(resolve(SRC, 'components/ui/ConfirmDialog.vue'), 'utf8')
    const propio = Number(dialog.match(/\.cd-overlay\s*\{[^}]*z-index:\s*(\d+)/)[1])

    const masAltos = []
    for (const f of archivos) {
      if (f.endsWith('ConfirmDialog.vue') || f.endsWith('App.vue')) continue   // App.vue: la barra de carga (99999)
      for (const m of readFileSync(f, 'utf8').matchAll(/z-index:\s*(\d+)/g)) {
        if (Number(m[1]) >= propio) masAltos.push(`${f.replace(SRC, '')}: ${m[1]}`)
      }
    }
    expect(masAltos, `Hay overlays por encima del cartel de confirmación (${propio}):\n${masAltos.join('\n')}`).toEqual([])
  })
})
