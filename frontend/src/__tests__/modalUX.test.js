import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { vModal } from '../directives/modal.js'
import { useConfirm } from '../composables/useConfirm.js'

const SRC = resolve(dirname(fileURLToPath(import.meta.url)), '..')

// AC: todo modal se abre con el cursor en su primer campo y se cierra con ESC.
//
// Antes esto vivía en ~20 modales, cada uno a su manera, y en los otros 55 no existía: la misma
// regla escrita en veinte lados y ausente en el resto. Ahora es una directiva y va en el overlay.

// En jsdom `(pointer: fine)` no existe, y sin esto el foco no se prueba nunca.
function conMouse(vale = true) {
  window.matchMedia = vi.fn().mockReturnValue({ matches: vale, addEventListener() {}, removeEventListener() {} })
}

const Modal = {
  directives: { modal: vModal },
  props: { opts: { type: [Function, Object], required: true } },
  template: `
    <div v-modal="opts" class="x__overlay">
      <div class="x__modal">
        <button class="primero">no soy campo</button>
        <input class="busca" type="text" />
        <input class="otro" type="text" />
      </div>
    </div>`,
}

const esc = () => document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))

describe('v-modal — foco y ESC', () => {
  let w
  beforeEach(() => conMouse(true))
  afterEach(() => { w?.unmount(); w = null; useConfirm().state.open = false })

  it('al abrir, el cursor va al primer CAMPO y no al primer botón', async () => {
    w = mount(Modal, { props: { opts: () => {} }, attachTo: document.body })
    await new Promise((r) => requestAnimationFrame(r))

    expect(document.activeElement.className).toBe('busca')
  })

  it('en el teléfono no enfoca nada: el teclado taparía medio modal', async () => {
    conMouse(false)
    w = mount(Modal, { props: { opts: () => {} }, attachTo: document.body })
    await new Promise((r) => requestAnimationFrame(r))

    expect(document.activeElement.className).not.toBe('busca')
  })

  it('ESC cierra', async () => {
    const cerrar = vi.fn()
    w = mount(Modal, { props: { opts: cerrar }, attachTo: document.body })

    esc()
    await new Promise((r) => setTimeout(r, 0))
    expect(cerrar).toHaveBeenCalled()
  })

  it('deja de escuchar al desmontarse: un modal cerrado no puede seguir reaccionando', async () => {
    const cerrar = vi.fn()
    w = mount(Modal, { props: { opts: cerrar }, attachTo: document.body })
    w.unmount(); w = null

    esc()
    await new Promise((r) => setTimeout(r, 0))
    expect(cerrar).not.toHaveBeenCalled()
  })

  // Con un modal encima de otro, ESC tiene que cerrar el de ARRIBA. Si cerrara el de abajo,
  // desaparecería el formulario y quedaría flotando la confirmación de algo que ya no existe.
  it('con dos modales abiertos, cierra el de arriba', async () => {
    const abajo = vi.fn(); const arriba = vi.fn()
    const a = mount(Modal, { props: { opts: abajo }, attachTo: document.body })
    const b = mount(Modal, { props: { opts: arriba }, attachTo: document.body })

    esc()
    await new Promise((r) => setTimeout(r, 0))
    expect(arriba).toHaveBeenCalled()
    expect(abajo).not.toHaveBeenCalled()

    a.unmount(); b.unmount()
  })
})

describe('v-modal — ESC con trabajo a medio hacer', () => {
  let w
  beforeEach(() => conMouse(true))
  afterEach(() => { w?.unmount(); w = null; useConfirm().state.open = false })

  it('si no se tocó nada, cierra sin preguntar', async () => {
    const cerrar = vi.fn()
    w = mount(Modal, { props: { opts: cerrar }, attachTo: document.body })

    esc()
    await new Promise((r) => setTimeout(r, 0))
    expect(useConfirm().state.open).toBe(false)
    expect(cerrar).toHaveBeenCalled()
  })

  // ESC se aprieta sin mirar: perder una dispensa a medio armar por eso duele.
  it('si la persona escribió algo, pregunta antes de cerrar', async () => {
    const cerrar = vi.fn()
    w = mount(Modal, { props: { opts: cerrar }, attachTo: document.body })

    await w.find('.busca').setValue('fede')
    esc()
    await new Promise((r) => setTimeout(r, 0))

    expect(useConfirm().state.open).toBe(true)
    expect(cerrar).not.toHaveBeenCalled()

    useConfirm().accept()
    await new Promise((r) => setTimeout(r, 0))
    expect(cerrar).toHaveBeenCalled()
  })

  it('si dice que no, el modal sigue abierto', async () => {
    const cerrar = vi.fn()
    w = mount(Modal, { props: { opts: cerrar }, attachTo: document.body })

    await w.find('.busca').setValue('fede')
    esc()
    await new Promise((r) => setTimeout(r, 0))
    useConfirm().cancel()
    await new Promise((r) => setTimeout(r, 0))

    expect(cerrar).not.toHaveBeenCalled()
  })

  // El carrito de la dispensa son divs, no campos: el chequeo genérico no lo ve.
  it('el modal puede declarar que tiene datos aunque nadie haya tecleado', async () => {
    const cerrar = vi.fn()
    w = mount(Modal, { props: { opts: { cerrar, sucio: () => true } }, attachTo: document.body })

    esc()
    await new Promise((r) => setTimeout(r, 0))
    expect(useConfirm().state.open).toBe(true)
    expect(cerrar).not.toHaveBeenCalled()
  })

  // Un modal de edición nace con los campos llenos. Si eso contara como "sucio", preguntaría
  // siempre y la pregunta dejaría de significar algo.
  it('un campo precargado por código NO cuenta como sucio', async () => {
    const cerrar = vi.fn()
    const Precargado = {
      directives: { modal: vModal },
      props: { opts: { type: [Function, Object], required: true } },
      data: () => ({ valor: 'ya venía escrito' }),
      template: `<div v-modal="opts" class="x__overlay"><input v-model="valor" /></div>`,
    }
    w = mount(Precargado, { props: { opts: cerrar }, attachTo: document.body })

    esc()
    await new Promise((r) => setTimeout(r, 0))
    expect(useConfirm().state.open).toBe(false)
    expect(cerrar).toHaveBeenCalled()
  })
})

// Que la directiva ande no sirve si un modal nuevo nace sin ella.
describe('Todos los modales usan la directiva', () => {
  function archivos(dir) {
    return readdirSync(dir).flatMap((n) => {
      const ruta = join(dir, n)
      if (statSync(ruta).isDirectory()) return archivos(ruta)
      return n.endsWith('.vue') ? [ruta] : []
    })
  }

  // Las dos únicas cosas con pinta de overlay que NO son modales:
  //   · ActionsDropdown es un MENÚ. Enfocarle un campo estaría mal, y cierra solo al clickear.
  //   · StockQrView es una PANTALLA entera (el destino del QR); su "overlay" es el fondo de la
  //     página, no tapa nada y no hay nada que cerrar.
  //   · ConfirmDialog es la capa de ARRIBA de todo, incluida la pregunta que hace la propia
  //     directiva antes de cerrar un modal sucio. Tiene su ESC propio y la directiva la saltea
  //     (`if (state.open) return`); meterla en la pila sólo le serviría para robarse el foco.
  const EXCEPCIONES = [
    'components/ui/ActionsDropdown.vue',
    'views/StockQrView.vue',
    'components/ui/ConfirmDialog.vue',
  ]

  it('cada overlay lleva v-modal', () => {
    const sinDirectiva = []
    for (const f of archivos(SRC)) {
      const rel = f.slice(SRC.length + 1)
      if (rel.startsWith('__tests__') || EXCEPCIONES.includes(rel)) continue

      for (const [linea] of readFileSync(f, 'utf8')
        // Conviven DOS convenciones de nombre —BEM (`mnd__overlay`) y guion (`mp-overlay`,
        // `mv-ov`)— y la primera versión de este barrido sólo miraba la BEM: 56 modales
        // parecían cubiertos y no lo estaban.
        .matchAll(/<div[^>]*class="[a-z0-9-]*(?:__|-)?(?:overlay|backdrop|ov)"[^>]*>/g)) {
        if (!linea.includes('v-modal')) sinDirectiva.push(`${rel}: ${linea.slice(0, 70)}…`)
      }
    }

    expect(sinDirectiva, 'estos overlays no cierran con ESC ni enfocan su primer campo').toEqual([])
  })
})
