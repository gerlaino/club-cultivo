import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// AC (23-oct-2026, Javi y Germán): la portada se parte en organizaciones (con los dos planes) y
// autocultivo, cada una con su color; los precios y límites salen del backend (sin respuesta, no
// aparece ningún número); arriba hay «Soy paciente»; el pie tiene los legales y el botón de
// arrepentimiento en todas las páginas. Al paciente el login no le ofrece «olvidé mi contraseña»,
// que el backend no le deja usar.
const PRECIOS = {
  moneda: 'USD',
  autocultivo: { precio: 8 },
  escalones: [
    { clave: 'basico', label: 'Hasta 50 pacientes', un_pack: 200, dos_packs: 350, plantas_floracion: 450, salas: 3, sedes: 1, usuarios_por_rol: 2, por_sede: false },
    { clave: 'total', label: 'Hasta 100 pacientes', un_pack: 400, dos_packs: 700, plantas_floracion: 900, salas: null, sedes: 3, usuarios_por_rol: 2, por_sede: true },
  ],
  pack_pacientes: { pacientes: 10, precio: 80 },
  sede_extra: 50,
}
window.scrollTo = () => {}
let respuesta
vi.mock('../lib/api.js', () => ({ getRegistroInfo: () => respuesta() }))
vi.mock('../lib/fuentesHerbario.js', () => ({ cargarFuentesHerbario: () => {} }))
let query = {}
vi.mock('vue-router', () => ({
  useRoute: () => ({ query, hash: '' }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}))

const stubs = {
  RouterLink: { props: ['to'], template: '<a :data-to="typeof to === \'string\' ? to : (to.path + (to.hash || \'\'))"><slot /></a>' },
  PlantaCreciendo: true, DsSpinner: true,
}
const montarPortada = async () => {
  const { default: V } = await import('../views/LandingView.vue')
  const w = mount(V, { global: { stubs } })
  await flushPromises()
  return w
}

describe('La portada pública', () => {
  beforeEach(() => { respuesta = () => Promise.resolve({ data: { dias_prueba: 30, precios: PRECIOS } }) })

  it('muestra los dos planes con sus precios y límites del backend', async () => {
    const w = await montarPortada()
    const planes = w.findAll('.lp__plan')
    expect(planes).toHaveLength(2)
    expect(planes[0].text()).toContain('Hasta 50 pacientes')
    expect(planes[0].text()).toContain('US$ 200')
    expect(planes[0].text()).toContain('US$ 350')
    expect(planes[0].text()).toContain('1 sede y 3 salas')
    expect(planes[0].text()).toContain('Hasta 450 plantas en floración')
    expect(planes[1].text()).toContain('3 sedes y salas libres')
    expect(planes[1].text()).toContain('2 personas de cada rol, en cada sede')
    expect(planes[1].text()).toContain('sedes extra')
  })

  it('un precio que cambia en el backend cambia en la portada', async () => {
    respuesta = () => Promise.resolve({ data: { dias_prueba: 14, precios: { ...PRECIOS, escalones: [{ ...PRECIOS.escalones[0], un_pack: 230 }] } } })
    const w = await montarPortada()
    expect(w.find('.lp__plan').text()).toContain('US$ 230')
    expect(w.text()).toContain('Probar 14 días gratis')
  })

  it('sin respuesta del backend no aparece ningún precio inventado', async () => {
    respuesta = () => Promise.reject(new Error('sin red'))
    const w = await montarPortada()
    expect(w.findAll('.lp__plan')).toHaveLength(0)
    expect(w.find('.lp__auto-p').exists()).toBe(false)
    expect(w.text()).not.toContain('US$')
  })

  it('autocultivo tiene su precio y lleva al registro; organizaciones, a su página y al contacto', async () => {
    const w = await montarPortada()
    expect(w.find('.lp__auto').text()).toContain('US$ 8')
    const destinos = w.findAll('a').map(a => a.attributes('data-to'))
    expect(destinos).toContain('/registro')
    expect(destinos).toContain('/bienvenida/organizaciones')
    expect(destinos).toContain('/bienvenida/organizaciones#precios')
    expect(destinos).toContain('/bienvenida/organizaciones#contacto')
  })
})

describe('El armado de las páginas públicas', () => {
  it('tiene «Soy paciente» arriba y, en el pie, los legales y el botón de arrepentimiento', async () => {
    const { default: P } = await import('../components/public/PaginaPublica.vue')
    const w = mount(P, { global: { stubs } })
    expect(w.find('.pp__paciente').attributes('data-to')).toBe('/paciente')
    const pie = w.find('footer')
    expect(pie.text()).toContain('Términos y condiciones')
    expect(pie.text()).toContain('Política de privacidad')
    expect(pie.find('.pp__arrep').text()).toBe('Botón de arrepentimiento')
    expect(pie.text()).toContain('Todos los derechos reservados')
    expect(pie.text()).toContain('no vende ni entrega cannabis')
  })
})

describe('El login desde «Soy paciente»', () => {
  it('le explica al paciente su usuario y no le ofrece «olvidé mi contraseña»', async () => {
    query = { paciente: '1' }
    const { createPinia, setActivePinia } = await import('pinia')
    setActivePinia(createPinia())
    const { default: L } = await import('../views/LoginView.vue')
    const w = mount(L, { global: { stubs } })
    expect(w.text()).toContain('Tu portal de paciente')
    expect(w.text()).toContain('nombre.apellido@organizacion.paciente')
    expect(w.findAll('a').map(a => a.attributes('data-to'))).not.toContain('/olvide-contrasena')
    expect(w.text()).toContain('Pedile una nueva a tu organización')
    expect(w.text()).not.toContain('Probá gratis')
  })

  it('al equipo le sigue ofreciendo «olvidé mi contraseña»', async () => {
    query = {}
    const { default: L } = await import('../views/LoginView.vue')
    const w = mount(L, { global: { stubs } })
    expect(w.text()).toContain('Ingresá')
    expect(w.findAll('a').map(a => a.attributes('data-to'))).toContain('/olvide-contrasena')
  })
})
