import { describe, it, expect, afterEach } from 'vitest'
import { mount } from '@vue/test-utils'
import Lightbox from '../components/ui/Lightbox.vue'

const IMAGES = [
  { src: '/a.jpg', alt: 'Image A' },
  { src: '/b.jpg', alt: 'Image B' },
  { src: '/c.jpg', alt: 'Image C' },
]

afterEach(() => {
  document.body.style.overflow = ''
  // Clean up any teleported content
  document.querySelectorAll('.lb').forEach(el => el.remove())
})

describe('Lightbox', () => {
  it('renders teleported content when open=true', async () => {
    const w = mount(Lightbox, {
      attachTo: document.body,
      props: { images: IMAGES, index: 0, open: true },
    })
    await w.vm.$nextTick()
    expect(document.querySelector('.lb')).not.toBeNull()
    w.unmount()
  })

  it('does not render when open=false', async () => {
    const w = mount(Lightbox, {
      attachTo: document.body,
      props: { images: IMAGES, index: 0, open: false },
    })
    await w.vm.$nextTick()
    expect(document.querySelector('.lb')).toBeNull()
    w.unmount()
  })

  it('shows current image src', async () => {
    const w = mount(Lightbox, {
      attachTo: document.body,
      props: { images: IMAGES, index: 1, open: true },
    })
    await w.vm.$nextTick()
    const img = document.querySelector('.lb__img')
    expect(img?.getAttribute('src')).toBe('/b.jpg')
    w.unmount()
  })

  it('shows counter with multiple images', async () => {
    const w = mount(Lightbox, {
      attachTo: document.body,
      props: { images: IMAGES, index: 0, open: true },
    })
    await w.vm.$nextTick()
    expect(document.querySelector('.lb__counter')?.textContent).toContain('1 / 3')
    w.unmount()
  })

  it('emits close when close button clicked', async () => {
    const w = mount(Lightbox, {
      attachTo: document.body,
      props: { images: IMAGES, index: 0, open: true },
    })
    await w.vm.$nextTick()
    document.querySelector('button.lb__btn')?.click()
    await w.vm.$nextTick()
    expect(w.emitted('close')).toBeTruthy()
    w.unmount()
  })

  it('ofrece descargar la imagen que se está viendo, con su nombre', async () => {
    const w = mount(Lightbox, {
      attachTo: document.body,
      props: { images: IMAGES, index: 1, open: true },
    })
    await w.vm.$nextTick()
    const a = document.querySelector('a.lb__btn')
    expect(a?.getAttribute('href')).toBe('/b.jpg')
    expect(a?.getAttribute('download')).toBe('imagen')
    w.unmount()
  })

  // Un adjunto de R2 es otro origen: ahí el atributo `download` no alcanza y hay que bajar por
  // una URL distinta (la de `disposition=attachment`). Por eso `descarga` gana sobre `src`.
  it('cuando hay una url de descarga propia, baja de esa y no de la que muestra', async () => {
    const w = mount(Lightbox, {
      attachTo: document.body,
      props: {
        images: [{ src: '/ver.jpg', alt: 'Comprobante', nombre: 'comprobante.jpg', descarga: '/bajar.jpg?disposition=attachment' }],
        index: 0,
        open: true,
      },
    })
    await w.vm.$nextTick()
    const a = document.querySelector('a.lb__btn')
    expect(a?.getAttribute('href')).toBe('/bajar.jpg?disposition=attachment')
    expect(a?.getAttribute('download')).toBe('comprobante.jpg')
    w.unmount()
  })

  it('emits update:index with next index on ArrowRight key', async () => {
    const w = mount(Lightbox, {
      attachTo: document.body,
      props: { images: IMAGES, index: 0, open: true },
    })
    await w.vm.$nextTick()
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight' }))
    await w.vm.$nextTick()
    expect(w.emitted('update:index')?.[0]).toEqual([1])
    w.unmount()
  })

  it('wraps to last on ArrowLeft from index 0', async () => {
    const w = mount(Lightbox, {
      attachTo: document.body,
      props: { images: IMAGES, index: 0, open: true },
    })
    await w.vm.$nextTick()
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft' }))
    await w.vm.$nextTick()
    expect(w.emitted('update:index')?.[0]).toEqual([2])
    w.unmount()
  })

  it('emits close on Escape key', async () => {
    const w = mount(Lightbox, {
      attachTo: document.body,
      props: { images: IMAGES, index: 0, open: true },
    })
    await w.vm.$nextTick()
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    await w.vm.$nextTick()
    expect(w.emitted('close')).toBeTruthy()
    w.unmount()
  })
})
