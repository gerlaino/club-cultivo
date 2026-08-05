import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

// El store importa la API real; la mockeamos entera para controlar los tiempos.
const mocks = vi.hoisted(() => ({
  me: vi.fn(),
  signIn: vi.fn(),
  signOut: vi.fn(),
  clearAuthToken: vi.fn(),
}))

vi.mock('../lib/api', () => mocks)
vi.mock('../stores/club.js', () => ({ useClubStore: () => ({ fetch: vi.fn() }) }))
vi.mock('../composables/usePlan.js', () => ({ usePlan: () => ({ planData: { value: null } }) }))
vi.mock('../router', () => ({ default: { push: vi.fn() } }))

const { useAuthStore } = await import('../stores/auth')

const diferido = () => {
  let resolver, rechazar
  const promesa = new Promise((res, rej) => { resolver = res; rechazar = rej })
  return { promesa, resolver, rechazar }
}

describe('bootstrap de sesión', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  // AC: el botón de "Ingresar" sólo se bloquea por el login del usuario, nunca por el /me
  // del arranque. Compartir el flag dejaba el formulario trabado sin que nadie apretara nada.
  it('el /me del arranque no toca el loading del formulario', async () => {
    const pendiente = diferido()
    mocks.me.mockReturnValue(pendiente.promesa)
    const auth = useAuthStore()

    auth.ensureBootstrapped()
    await Promise.resolve()

    expect(auth.loading).toBe(false)

    pendiente.resolver({ data: { id: 1, role: 'admin' } })
    await pendiente.promesa
  })

  // main.js hacía `auth.fetchMe()` directo en cada arranque, y eso levantaba `loading`:
  // el botón de login quedaba deshabilitado con spinner sin que nadie lo hubiera tocado.
  // Ni llamándolo a mano puede bloquear el formulario.
  it('fetchMe NUNCA bloquea el formulario, ni llamado directo', async () => {
    const pendiente = diferido()
    mocks.me.mockReturnValue(pendiente.promesa)
    const auth = useAuthStore()

    auth.fetchMe()
    await Promise.resolve()

    expect(auth.loading).toBe(false)

    pendiente.resolver({ data: { id: 1 } })
    await pendiente.promesa
    expect(auth.loading).toBe(false)
  })

  // AC: dos navegaciones seguidas antes de que resuelva la primera = UNA sola request.
  it('no dispara dos /me en paralelo', async () => {
    const pendiente = diferido()
    mocks.me.mockReturnValue(pendiente.promesa)
    const auth = useAuthStore()

    auth.ensureBootstrapped()
    auth.ensureBootstrapped()
    auth.ensureBootstrapped()
    await Promise.resolve()

    expect(mocks.me).toHaveBeenCalledTimes(1)

    pendiente.resolver({ data: { id: 1 } })
    await pendiente.promesa
  })

  // AC (el bug que rompió el login dos veces): el /me del arranque sale SIN cookie y vuelve
  // 401. Si vuelve DESPUÉS de que el usuario ya se logueó, no puede borrar esa sesión.
  it('un 401 tardío del arranque no pisa un login posterior', async () => {
    const bootstrap = diferido()
    mocks.me.mockReturnValueOnce(bootstrap.promesa)
    const auth = useAuthStore()

    auth.ensureBootstrapped()          // queda en vuelo
    await Promise.resolve()

    // El usuario se loguea mientras tanto: signIn OK y su propio /me responde al toque.
    mocks.signIn.mockResolvedValue({})
    mocks.me.mockResolvedValueOnce({ data: { id: 7, role: 'dispensador' } })
    await auth.login('a@b.com', 'secreto')

    expect(auth.isAuthenticated).toBe(true)

    // Recién ahora vuelve el /me viejo, con 401.
    bootstrap.rechazar({ response: { status: 401 } })
    await new Promise((r) => setTimeout(r, 0))

    expect(auth.isAuthenticated).toBe(true)
    expect(auth.user.id).toBe(7)
  })

  it('el login sí bloquea su propio botón mientras corre', async () => {
    const pendiente = diferido()
    mocks.signIn.mockReturnValue(pendiente.promesa)
    const auth = useAuthStore()

    const enCurso = auth.login('a@b.com', 'x')
    await Promise.resolve()
    expect(auth.loading).toBe(true)

    pendiente.rechazar({ response: { status: 401 } })
    await enCurso.catch(() => {})

    expect(auth.loading).toBe(false)
    expect(auth.error).toBe('Credenciales inválidas')
  })
})
