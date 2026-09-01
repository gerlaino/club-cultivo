// Lo compartido por los casos: entrar como cada persona y un par de atajos.
//
// Las credenciales salen de `rake e2e:seed`. Si cambian allá, cambian acá — es la única
// duplicación aceptable, porque el seed vive en el backend y el test en el frontend.
import { execSync } from 'node:child_process'

// Cada archivo siembra SU escenario antes de correr. Sin esto los casos comparten el mismo
// mostrador —uno solo por sede, igual que en la vida real— y se pisan según el orden en que
// corran, que es la peor clase de prueba: la que falla distinto cada vez.
//
// Shellea a docker a propósito: el estado lo arma el backend, que es el que sabe. Reimplementar
// el escenario por API desde acá sería una segunda verdad sobre cómo se ve una organización.
export function sembrar (...tareas) {
  const cmd = tareas.map(t => `bundle exec rake e2e:${t}`).join(' && ')
  try {
    execSync(`docker compose exec -T backend sh -lc '${cmd}'`, {
      cwd: new URL('../..', import.meta.url).pathname, stdio: 'pipe',
    })
  } catch (e) {
    // Sin el entorno arriba, `docker compose exec` falla con un error de shell que no dice nada
    // de lo que pasa. La causa es siempre la misma y la solución también: la primera vez que
    // alguien corre esto, el mensaje tiene que decírselo.
    const salida = [e.stderr?.toString(), e.stdout?.toString()].filter(Boolean).join('\n').trim()
    throw new Error(
      'No se pudo sembrar el escenario en el backend.\n' +
      'Estas pruebas necesitan el entorno andando: levantá `docker compose up` y volvé a correr.\n' +
      (salida ? `\nLo que dijo docker:\n${salida}` : '')
    )
  }
}

// La API vive en otro puerto: el dev server de Vite no proxea, así que la verificación de sesión
// pega al backend directo, con credenciales, igual que la app.
export const API = process.env.E2E_API || 'http://localhost:3001/api'
export const CLAVE = 'E2eTest2026!'
export const USUARIOS = {
  admin:       'admin@e2e.test',
  dispensador: 'dispensador@e2e.test',
  delivery:    'delivery@e2e.test',
}

export async function entrar (page, quien) {
  // La sesión vive en una cookie httpOnly y el store queda en memoria: sin limpiar las dos,
  // `/login` redirige al tablero del que ya estaba y el caso sigue con el usuario anterior sin
  // que nada falle. Es la trampa que hace que una prueba multi-usuario pase estando mal.
  // `about:blank` primero: si queda una petición en vuelo, su `Set-Cookie` llega DESPUÉS de
  // limpiar y repone la sesión del usuario anterior. Se descubre tres pasos más adelante con un
  // error que no tiene nada que ver.
  await page.goto('about:blank')
  await page.context().clearCookies()
  await page.goto('/login')
  await page.evaluate(() => { localStorage.clear(); sessionStorage.clear() })
  await page.context().clearCookies()
  await page.goto('/login')
  await page.waitForSelector('input[type="password"]', { timeout: 15_000 })

  await page.fill('input[type="email"], input[name="email"]', USUARIOS[quien])
  await page.fill('input[type="password"]', CLAVE)
  await page.click('button[type="submit"]')
  await page.waitForURL(u => !u.pathname.includes('/login'), { timeout: 20_000 })

  // Y se VERIFICA con quién entró. Sin esto, un login que no cambió de usuario se descubre tres
  // pasos después, con un error que no tiene nada que ver.
  const email = await page.evaluate(async (base) => {
    const r = await fetch(`${base}/me`, { credentials: 'include' })
    if (!r.ok) return null
    const j = await r.json()
    return j?.email || j?.user?.email || j?.data?.email || null
  }, API)
  if (email !== USUARIOS[quien]) {
    throw new Error(`Se esperaba entrar como ${USUARIOS[quien]} y la sesión es de ${email || '(nadie)'}`)
  }
}

// Falla el caso si la pantalla tiró un error de JS. Un build verde no prueba que ande: en este
// proyecto ya pasó cuatro veces que algo compilara perfecto y explotara al abrirse.
export function vigilarErrores (page) {
  const errores = []
  page.on('pageerror', e => errores.push(`pageerror: ${e.message}`))
  page.on('console', m => {
    if (m.type() === 'error' && !m.text().includes('401')) errores.push(`console: ${m.text()}`)
  })
  return errores
}

// Elige una opción por lo que DICE, no por su posición: el orden de un desplegable no está
// garantizado, y agarrar el producto equivocado hace fallar la prueba por algo que no se estaba
// probando. `selectOption({ label })` no acepta expresiones, así que se resuelve el value.
export async function elegirPorTexto (page, selector, texto) {
  const opcion = page.locator(`${selector} option`, { hasText: texto }).first()
  // `attached` y no `visible`: para Playwright un <option> nunca está "visible".
  await opcion.waitFor({ state: 'attached', timeout: 10_000 })
  await page.selectOption(selector, await opcion.getAttribute('value'))
}

// El id de un usuario del club, para ir derecho a su ficha. Buscarlo clickeando su nombre en la
// lista hace que la prueba dependa de dónde esté puesto ese texto.
export async function idDeUsuario (page, email) {
  return await page.evaluate(async ([base, mail]) => {
    const r = await fetch(`${base}/usuarios`, { credentials: 'include' })
    const j = await r.json()
    const lista = Array.isArray(j) ? j : (j.data || j.usuarios || [])
    return lista.find(u => u.email === mail)?.id ?? null
  }, [API, email])
}

export const num = (t) => Number(String(t).replace(/[^\d,-]/g, '').replace(/\./g, '').replace(',', '.'))
