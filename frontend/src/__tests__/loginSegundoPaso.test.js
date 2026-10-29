import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (29-oct-2026, seguridad tanda 2): el super admin entra con mail, clave Y el código de su app.
// Con la clave bien y sin código, el backend contesta 401 `necesita_codigo`: la pantalla pide el
// código y reenvía todo junto. Las demás cuentas no ven nada nuevo.
const api = vi.hoisted(() => ({ signIn: vi.fn(), me: vi.fn() }))
vi.mock('vue-router', () => ({ useRoute: () => ({ query: {} }), useRouter: () => ({ push: vi.fn() }) }))
vi.mock('../lib/api', () => ({ signIn: (...a) => api.signIn(...a), signOut: vi.fn(), me: (...a) => api.me(...a), clearAuthToken: vi.fn() }))
vi.mock('../stores/club.js', () => ({ useClubStore: () => ({ fetch: vi.fn(() => Promise.resolve()) }) }))
vi.mock('../composables/usePlan.js', () => ({ usePlan: () => ({}) }))
vi.mock('../lib/cachesSesion.js', () => ({ borrarCachesDeSesion: vi.fn(() => Promise.resolve()) }))
vi.mock('../router', () => ({ default: { push: vi.fn() }, puedeEntrar: () => true }))

const LoginView = (await import('../views/LoginView.vue')).default

function falla401(data) {
  return Object.assign(new Error('401'), { response: { status: 401, data } })
}

describe('Login con segundo paso', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    api.signIn.mockReset()
    api.me.mockReset()
    document.body.innerHTML = ''
  })

  const montar = () => mount(LoginView, { global: { stubs: { DsSpinner: true, RouterLink: true } }, attachTo: document.body })

  async function escribirYEntrar(w) {
    await w.find('#lv-usuario').setValue('german@plataforma.com')
    await w.find('#lv-pass').setValue('LaClave2026!')
    await w.find('form').trigger('submit')
    await flushPromises()
  }

  it('sin el código, lo pide con el mensaje del servidor; con el código, manda todo junto', async () => {
    api.signIn.mockRejectedValueOnce(falla401({ error: 'Escribí el código de seis números de tu app.', necesita_codigo: true }))
    const w = montar()
    expect(w.find('[data-testid="login-codigo"]').exists()).toBe(false)

    await escribirYEntrar(w)

    expect(w.find('[data-testid="login-codigo"]').exists()).toBe(true)
    expect(w.find('.hb-error').text()).toContain('código de seis números')
    expect(w.find('button[type="submit"]').attributes('disabled')).toBeDefined()

    api.signIn.mockResolvedValueOnce({ data: {} })
    api.me.mockResolvedValueOnce({ data: { id: 1, role: 'super_admin' } })
    await w.find('#lv-codigo').setValue('123456')
    await new Promise(r => setTimeout(r, 650)) // el anti doble click del formulario
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(api.signIn).toHaveBeenLastCalledWith('german@plataforma.com', 'LaClave2026!', '123456')
  })

  it('una clave equivocada no pide código', async () => {
    api.signIn.mockRejectedValueOnce(falla401({ error: 'Email o contraseña inválidos.' }))
    const w = montar()

    await escribirYEntrar(w)

    expect(w.find('[data-testid="login-codigo"]').exists()).toBe(false)
    expect(w.find('.hb-error').text()).toContain('Usuario o contraseña incorrectos.')
  })

  it('cambiar el usuario saca el campo del código', async () => {
    api.signIn.mockRejectedValueOnce(falla401({ error: 'Escribí el código.', necesita_codigo: true }))
    const w = montar()
    await escribirYEntrar(w)
    expect(w.find('[data-testid="login-codigo"]').exists()).toBe(true)

    await w.find('#lv-usuario').setValue('otra@cuenta.com')

    expect(w.find('[data-testid="login-codigo"]').exists()).toBe(false)
  })
})
