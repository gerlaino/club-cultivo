import { describe, it, expect, vi, beforeEach } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createMemoryHistory } from 'vue-router'
import DeliveryTopBar from '../components/layout/DeliveryTopBar.vue'

// El dashboard pide sus paquetes al montar. Se le devuelve un viaje con las tres situaciones
// (por retirar, en camino y uno que falló) para poder plegar de verdad las tres listas.
const PAQUETES = [
  { id: 1, estado_envio: 'pendiente', codigo_paquete: 'PKG-1', paciente: { nombre: 'Ana' },  direccion_envio: 'Calle 1' },
  { id: 2, estado_envio: 'pendiente', codigo_paquete: 'PKG-2', paciente: { nombre: 'Beto' }, direccion_envio: 'Calle 2' },
  { id: 3, estado_envio: 'en_viaje',  codigo_paquete: 'PKG-3', paciente: { nombre: 'Caro' }, direccion_envio: 'Calle 3' },
  { id: 4, estado_envio: 'fallido',   codigo_paquete: 'PKG-4', paciente: { nombre: 'Dani' }, direccion_envio: 'Calle 4', motivo_fallo: 'Nadie atendió' },
]

vi.mock('../lib/api.js', () => ({
  getMisPaquetes: vi.fn(() => Promise.resolve({ data: { dispensaciones: PAQUETES } })),
  iniciarViaje:   vi.fn(() => Promise.resolve({ data: {} })),
  ordenarRuta:    vi.fn(() => Promise.resolve({ data: {} })),
}))

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const leer = (rel) => readFileSync(resolve(raiz, rel), 'utf8')

// Un build que pasa NO prueba que la pantalla se vea bien: un template puede referenciar
// clases CSS que nadie definió y Vite compila igual, feliz. Ya pasó una vez (el modal
// contable salió sin estilos y compilaba perfecto), así que la regla se verifica sola.
function clasesDelTemplate(src) {
  // Se quitan los bloques <script> y <style>; lo que queda es el markup. No se puede asumir
  // que el template va primero: en DeliveryDashboard.vue el <script setup> abre el archivo.
  const template = src
    .replace(/<script[\s\S]*?<\/script>/g, '')
    .replace(/<style[\s\S]*?<\/style>/g, '')
  const clases = new Set()
  // class="a b c" y :class="{ 'a': cond, 'b': cond }"
  for (const m of template.matchAll(/\bclass="([^"]*)"/g)) {
    for (const c of m[1].split(/\s+/)) if (/^dlv[-_]/.test(c)) clases.add(c)
  }
  for (const m of template.matchAll(/:class="([^"]*)"/g)) {
    for (const c of m[1].matchAll(/'([^']+)'/g)) if (/^dlv[-_]/.test(c[1])) clases.add(c[1])
  }
  return [...clases]
}

function clasesDefinidas(src) {
  const estilo = src.slice(src.indexOf('<style'))
  return new Set([...estilo.matchAll(/\.([a-zA-Z0-9_-]+)/g)].map((m) => m[1]))
}

describe('Delivery — la pantalla que se ve, no la que compila', () => {
  const vistas = {
    'views/delivery/DeliveryDashboard.vue': 'dashboard',
    'components/layout/DeliveryTopBar.vue': 'topbar',
    'components/layout/DeliverySidebar.vue': 'sidebar',
  }

  for (const [ruta, nombre] of Object.entries(vistas)) {
    it(`${nombre}: toda clase dlv- del template está definida en su <style>`, () => {
      const src       = leer(ruta)
      const usadas    = clasesDelTemplate(src)
      const definidas = clasesDefinidas(src)

      expect(usadas.length).toBeGreaterThan(0)
      const huerfanas = usadas.filter((c) => !definidas.has(c))
      expect(huerfanas, `sin estilo en ${ruta}`).toEqual([])
    })
  }

  describe('el logout está donde está en el resto de la app', () => {
    const topbar  = leer('components/layout/DeliveryTopBar.vue')
    const sidebar = leer('components/layout/DeliverySidebar.vue')

    it('la topbar tiene el menú de usuario con Cerrar sesión', () => {
      expect(topbar).toContain('Cerrar sesión')
      expect(topbar).toContain('Mi perfil')
      expect(topbar).toContain('handleLogout')
    })

    // El sidebar se esconde en mobile (@media max-width:1023px) y el delivery trabaja
    // siempre desde el celular: el logout no puede depender de abrir la hamburguesa.
    it('el sidebar ya no es el único lugar donde salir', () => {
      expect(sidebar).not.toContain('dlv-logout')
    })

    // Montado de verdad: que el markup exista no prueba que el panel se abra. El botón vive
    // dentro del slot #panel de DsDropdown, que sólo renderiza cuando el v-model es true.
    it('el botón aparece al tocar el avatar', async () => {
      setActivePinia(createPinia())
      const router = createRouter({
        history: createMemoryHistory(),
        routes: [
          { path: '/', component: { template: '<div/>' } },
          { path: '/perfil', component: { template: '<div/>' } },
        ],
      })
      await router.push('/')
      await router.isReady()

      const wrapper = mount(DeliveryTopBar, { global: { plugins: [createPinia(), router] } })

      expect(wrapper.text()).not.toContain('Cerrar sesión')

      await wrapper.get('.dlv-avatar-btn').trigger('click')

      expect(wrapper.text()).toContain('Cerrar sesión')
      expect(wrapper.text()).toContain('Mi perfil')
    })
  })

  describe('secciones plegables', () => {
    const dash = leer('views/delivery/DeliveryDashboard.vue')

    it('las tres listas se pliegan', () => {
      const heads = dash.match(/class="dlv__section-head"/g) || []
      expect(heads).toHaveLength(3)
      expect(dash).toContain("toggleSeccion('pendientes')")
      expect(dash).toContain("toggleSeccion('enviaje')")
      expect(dash).toContain("toggleSeccion('fallidos')")
    })

    it('cada lista se muestra según su sección', () => {
      expect(dash).toContain('v-show="abiertas.pendientes"')
      expect(dash).toContain('v-show="abiertas.enviaje"')
      expect(dash).toContain('v-show="abiertas.fallidos"')
    })

    // Las tres arrancan abiertas. Los fallidos estuvieron cerrados por defecto y se leía como
    // que la entrega fallida no se había registrado: reportabas el fallo, volvías y no estaba.
    it('las tres arrancan abiertas', () => {
      expect(dash).toMatch(/abiertas\s*=\s*ref\(\{\s*pendientes:\s*true,\s*enviaje:\s*true,\s*fallidos:\s*true\s*\}\)/)
    })

    it('recuerda la elección entre viajes', () => {
      expect(dash).toContain('dlv_secciones_plegadas')
      expect(dash).toContain('localStorage.setItem')
    })
  })

  // Montado de verdad, con paquetes en las tres situaciones: que el v-show esté escrito no
  // prueba que la lista se esconda al tocar la cabecera.
  describe('el plegado, funcionando', () => {
    beforeEach(() => {
      localStorage.clear()
      setActivePinia(createPinia())
    })

    async function montarDashboard() {
      const router = createRouter({
        history: createMemoryHistory(),
        routes: [{ path: '/', component: { template: '<div/>' } }],
      })
      await router.push('/')
      await router.isReady()

      const { default: DeliveryDashboard } = await import('../views/delivery/DeliveryDashboard.vue')
      const wrapper = mount(DeliveryDashboard, {
        global: { plugins: [createPinia(), router], stubs: { Teleport: true } },
      })
      await flush()
      return wrapper
    }

    const flush = async () => {
      for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))
    }

    const visible = (el) => el.attributes('style') !== 'display: none;'

    it('pinta una cabecera por lista, con su contador', async () => {
      const wrapper = await montarDashboard()
      const heads = wrapper.findAll('.dlv__section-head')

      expect(heads).toHaveLength(3)
      expect(heads[0].text()).toContain('Pendientes de retirar')
      expect(heads[0].find('.dlv__section-count').text()).toBe('2')
      expect(heads[1].find('.dlv__section-count').text()).toBe('1')
    })

    it('al tocar la cabecera, la lista se esconde y vuelve', async () => {
      const wrapper = await montarDashboard()
      const head = wrapper.findAll('.dlv__section-head')[0]
      const lista = () => wrapper.findAll('.dlv__list')[0]

      expect(visible(lista())).toBe(true)

      await head.trigger('click')
      expect(visible(lista())).toBe(false)

      await head.trigger('click')
      expect(visible(lista())).toBe(true)
    })

    it('los fallidos se ven sin tener que desplegar nada', async () => {
      const wrapper = await montarDashboard()
      const listas = wrapper.findAll('.dlv__list')

      expect(visible(listas[listas.length - 1])).toBe(true)
      expect(wrapper.text()).toContain('PKG-4')     // el paquete que falló
    })

    it('la elección sobrevive a recargar la app', async () => {
      const primero = await montarDashboard()
      await primero.findAll('.dlv__section-head')[0].trigger('click')

      const segundo = await montarDashboard()
      expect(visible(segundo.findAll('.dlv__list')[0])).toBe(false)
    })
  })
})
