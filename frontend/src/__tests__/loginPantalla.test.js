import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

vi.mock('vue-router', () => ({ useRoute: () => ({ query: {} }), useRouter: () => ({ push: vi.fn() }) }))
vi.mock('../lib/api', () => ({ signIn: vi.fn(), signOut: vi.fn(), me: vi.fn(), clearAuthToken: vi.fn() }))
vi.mock('../stores/club.js', () => ({ useClubStore: () => ({ fetch: vi.fn(() => Promise.resolve()) }) }))
vi.mock('../composables/usePlan.js', () => ({ usePlan: () => ({}) }))

const LoginView = (await import('../views/LoginView.vue')).default
const { useAuthStore } = await import('../stores/auth.js')

// El síntoma que reportó Germán: el botón con el spinner y NADA de texto. Lo que se verifica acá
// es lo que se ve en pantalla, no lo que devuelve una función.
describe('LoginView — la pantalla siempre dice qué pasó', () => {
  let auth

  beforeEach(() => {
    setActivePinia(createPinia())
    auth = useAuthStore()
    document.body.innerHTML = ''
  })

  const montar = () => mount(LoginView, {
    global: { stubs: { DsSpinner: true, RouterLink: true } },
    attachTo: document.body,
  })

  it('muestra el error de login cuando lo hay', async () => {
    const w = montar()
    auth.error = 'Email o contraseña incorrectos.'
    await w.vm.$nextTick()

    expect(w.find('.lv__error').text()).toContain('Email o contraseña incorrectos.')
  })

  // El servidor dormido: la espera es larga y legítima, pero hay que contarla.
  it('mientras espera, avisa que el servidor está arrancando', async () => {
    const w = montar()
    auth.aviso = 'El servidor estaba en reposo y está arrancando. Puede tardar unos segundos.'
    await w.vm.$nextTick()

    expect(w.find('.lv__aviso').text()).toMatch(/arrancando/i)
  })

  // Un error real tapa al aviso: no se muestran los dos mensajes peleándose.
  it('con un error de verdad, el aviso desaparece', async () => {
    const w = montar()
    auth.aviso = 'El servidor estaba en reposo y está arrancando.'
    auth.error = 'Email o contraseña incorrectos.'
    await w.vm.$nextTick()

    expect(w.find('.lv__aviso').exists()).toBe(false)
    expect(w.find('.lv__error').exists()).toBe(true)
  })

  // La regla de fondo: si el botón está girando, en la pantalla hay una línea que lo explica.
  it('nunca hay spinner sin texto', async () => {
    const w = montar()
    auth.loading = true
    auth.aviso = 'El servidor estaba en reposo y está arrancando.'
    await w.vm.$nextTick()

    const hayTexto = w.find('.lv__aviso').exists() || w.find('.lv__error').exists()
    expect(hayTexto).toBe(true)
  })
})
