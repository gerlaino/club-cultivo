import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const leer = (rel) => readFileSync(resolve(raiz, rel), 'utf8')

const GENETICAS = [
  { id: 1, nombre: 'ANANDA001', registrada_inase: true,  numero_registro_inase: 'INASE-12345' },
  { id: 2, nombre: 'CELOSA 10', registrada_inase: true,  numero_registro_inase: 'INASE-67890' },
  { id: 3, nombre: 'Northern Lights', registrada_inase: false, declarada_como_id: null },
]

vi.mock('../lib/api.js', () => ({
  default: { get: vi.fn(() => Promise.resolve({ data: {} })) },
  listGeneticas:  vi.fn(() => Promise.resolve({ data: GENETICAS })),
  getGenetica:    vi.fn((id) => Promise.resolve({ data: GENETICAS.find((g) => g.id === id) })),
  createGenetica: vi.fn(() => Promise.resolve({ data: {} })),
  updateGenetica: vi.fn(() => Promise.resolve({ data: {} })),
}))

describe('Declarar una genética ante el INASE', () => {
  // Un template puede nombrar clases que nadie definió y Vite compila igual: la regla se
  // verifica sola (ya pasó con un modal que salió sin estilos).
  it('el modal no usa clases CSS inexistentes', () => {
    const src = leer('components/GeneticaEditarModal.vue')
    const markup = src
      .replace(/<script[\s\S]*?<\/script>/g, '')
      .replace(/<style[\s\S]*?<\/style>/g, '')
    const estilo = src.slice(src.indexOf('<style'))
    const definidas = new Set([...estilo.matchAll(/\.([a-zA-Z0-9_-]+)/g)].map((m) => m[1]))

    const usadas = new Set()
    for (const m of markup.matchAll(/\bclass="([^"]*)"/g)) {
      for (const c of m[1].split(/\s+/)) if (/^gem-form__/.test(c)) usadas.add(c)
    }

    expect(usadas.size).toBeGreaterThan(0)
    expect([...usadas].filter((c) => !definidas.has(c))).toEqual([])
  })

  describe('el selector, montado', () => {
    let wrapper

    beforeEach(async () => {
      setActivePinia(createPinia())
      const { default: Modal } = await import('../components/GeneticaEditarModal.vue')
      wrapper = mount(Modal, { global: { stubs: { Teleport: true } } })
      wrapper.vm.openCreate?.()
      await wrapper.vm.$nextTick()
      for (let i = 0; i < 4; i++) await new Promise((r) => setTimeout(r, 0))
    })

    it('ofrece las variedades inscriptas y ninguna otra', () => {
      const select = wrapper.findAll('select').at(-1)
      const opciones = select.findAll('option').map((o) => o.text())

      expect(opciones.some((t) => t.includes('ANANDA001'))).toBe(true)
      expect(opciones.some((t) => t.includes('CELOSA 10'))).toBe(true)
      // La no inscripta no puede ser destino de una declaración.
      expect(opciones.some((t) => t.includes('Northern Lights'))).toBe(false)
      expect(opciones[0]).toContain('Sin declarar')
    })

    it('muestra el número de registro junto al nombre', () => {
      const select = wrapper.findAll('select').at(-1)

      expect(select.text()).toContain('INASE-12345')
    })
  })
})
