import { test, expect } from '@playwright/test'
import { entrar, vigilarErrores, sembrar } from './helpers.js'

// El día completo del mostrador, tal cual lo hace la gente: el admin carga la mesa, el que
// atiende la recibe, dispensa y cierra contando.
//
// Es UNA sola prueba encadenada a propósito: cada paso depende del anterior, y partirla en casos
// independientes obligaría a rehacer el estado en cada uno o a inventar atajos por API — que es
// justo lo que estas pruebas existen para no hacer.
test.describe.configure({ mode: 'serial' })

// Arranca con el mostrador CERRADO y sin nada operativo.
test.beforeAll(() => sembrar('seed'))

test('el día del mostrador, de punta a punta', async ({ page }) => {
  const errores = vigilarErrores(page)

  // ── 1. Administración carga la mesa ────────────────────────────────────────
  // El día arranca con la mesa vacía y sin caja: el mostrador existe, pero no hay nada arriba.
  await entrar(page, 'admin')
  await page.goto('/mostrador')

  // La tabla del inventario, con DEPÓSITO y MOSTRADOR como dos columnas: de un vistazo se ve
  // dónde está cada producto.
  await page.fill('.tmo__buscar', 'flor seca')
  await expect(page.locator('.tmo__table tbody tr')).toHaveCount(1)
  const flor = page.locator('.tmo__table tbody tr').first()
  // El PRODUCTO es la forma y la VARIEDAD la genética: no el mismo dato dos veces.
  await expect(flor.locator('.tmo__prod')).toHaveText('Flor seca')
  await expect(flor).toContainText('E2E Kush')

  await flor.locator('.tmo__input').fill('300')
  await expect(page.locator('.tmo__pie')).toContainText('1 cambio sin guardar')
  // El motivo se pide en el modal, con la lista de lo que cambia delante: escrito a ciegas
  // terminaba diciendo "carga" en todos los renglones.
  await page.click('.mst__btn--guardar')
  await expect(page.locator('.cmm__row .cmm__ahora')).toContainText('300')
  // Un cambio de mesa sin motivo es un número que aparece: no se puede guardar.
  await expect(page.locator('.cmm__btn--primary')).toBeDisabled()
  await page.fill('.cmm__input', 'carga del lunes')
  await page.click('.cmm__btn--primary')
  await expect(page.locator('.tmo__pie')).toHaveCount(0, { timeout: 15_000 })
  await expect(page.locator('.tmo__table tbody tr').first().locator('.tmo__input')).toHaveValue('300')

  // ── 2. Quien atiende abre la caja contando ─────────────────────────────────
  await entrar(page, 'dispensador')
  await page.goto('/mostrador')
  // Él ve la mesa, pero no la edita: nunca elige qué hay.
  await expect(page.locator('.tmo__mesa').first()).toHaveText('300')
  // Lo que abre y cierra es LA CAJA: la mesa sigue teniendo los 300 g que se ven al lado.
  await expect(page.locator('.mst__estado')).toHaveText(/Caja cerrada/)
  await expect(page.locator('.tmo__input')).toHaveCount(0)

  await page.click('.mst__turno-acc .mst__btn')          // Abrir caja
  await expect(page.locator('.cnt__title')).toHaveText('Abrir caja')
  // Nadie pesa 297 teniendo el 297 delante: lo esperado no aparece hasta escribir el conteo.
  await expect(page.locator('.cnt__comparacion')).toHaveCount(0)
  await page.locator('.cnt__cant .cnt__input').first().fill('297')
  await page.locator('.cnt__input--plata').first().fill('20000')

  const comp = page.locator('.cnt__comparacion')
  await expect(comp).toContainText('Debería haber')
  await expect(comp).toContainText('300')
  await expect(comp).toContainText('−3')
  // La diferencia NO bloquea: se anota y se abre igual.
  await expect(comp).toContainText('podés abrir igual')
  await page.locator('.cnt__acc .cnt__btn--primary').click()

  await expect(page.locator('.mst__estado')).toHaveText(/Caja abierta/, { timeout: 15_000 })
  // La mesa pasa a tener lo que contó, y queda escrito qué pasó.
  await expect(page.locator('.tmo__mesa').first()).toHaveText('297')
  await expect(page.locator('.mst__aviso')).toContainText('contó 297')

  // ── 3. Cuenta UN producto a mitad del turno, sin cerrar ────────────────────
  // Cerrar y reabrir con quince frascos son veinte minutos: el control que cuesta eso no se hace.
  await page.locator('.tmo__contar').first().click()
  // Misma regla que el arqueo: lo esperado no aparece hasta que el conteo está escrito.
  await expect(page.locator('.cti__comparacion')).toHaveCount(0)
  await page.locator('.cti__input').first().fill('296')
  await expect(page.locator('.cti__comp-dif')).toContainText('−1')
  // Acá la diferencia SÍ ajusta el inventario, así que sin motivo no se puede registrar.
  await expect(page.locator('.cti__btn--primary')).toBeDisabled()
  await page.locator('.cti__input--texto').fill('se fraccionó para prerolls')
  await page.locator('.cti__btn--primary').click()
  await expect(page.locator('.tmo__mesa').first()).toHaveText('296', { timeout: 15_000 })

  // ── 4. Cierra contando, y ve la comparación ────────────────────────────────
  //
  // Al CERRAR los dos campos de plata llegan con un número: el efectivo con lo que tendría que
  // haber y el fondo con lo mismo ("dejo todo"), que es lo que la pantalla ya le dice a quien no
  // puede retirar. Vacío, el modal le anunciaba un retiro A SU NOMBRE que él no puede hacer.
  // Por eso la comparación aparece desde el vamos: ya hay algo escrito con qué comparar.
  await page.click('.mst__turno-acc .mst__btn')          // Cerrar caja
  await expect(page.locator('.cnt__input--plata').first()).toHaveValue('20000')
  await expect(page.locator('.cnt__comparacion')).toHaveCount(1)
  await page.locator('.cnt__cant .cnt__input').first().fill('295')
  await expect(page.locator('.cnt__comparacion')).toContainText('−1')
  await page.locator('.cnt__acc .cnt__btn--primary').click()

  await expect(page.locator('.mst__estado')).toHaveText(/Caja cerrada/, { timeout: 15_000 })
  // Y la mesa sigue teniendo lo que quedó: el producto está físicamente ahí aunque nadie atienda.
  await expect(page.locator('.tmo__mesa').first()).toHaveText('295')

  expect(errores, errores.join('\n')).toEqual([])
})

test('el admin ve la merma del turno que cerró', async ({ page }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'admin')
  await page.goto('/mostrador')

  await page.locator('.mst__tab', { hasText: 'Merma' }).click()
  // Arriba de todo, el VEREDICTO: un porcentaje solo no se compara con nada. Y siempre dice algo
  // —acá, que todavía no hay historia con qué comparar—, porque quedarse en blanco se lee como
  // que está todo bien.
  await expect(page.locator('.mrm__veredicto')).toBeVisible()
  await expect(page.locator('.mrm__ver-frase')).not.toBeEmpty()
  // Y UNA sola tabla, con un corte a la vez: eran cuatro apiladas con las mismas columnas.
  await expect(page.getByRole('heading', { name: 'Dónde se va' })).toBeVisible()
  await expect(page.locator('.mrm__cortes .mrm__periodo').first()).toHaveText('Por producto')
  await page.locator('.mrm__cortes .mrm__periodo', { hasText: 'Cierre por cierre' }).click()
  await expect(page.locator('.mrm__table th').first()).toHaveText('Cerró')

  expect(errores, errores.join('\n')).toEqual([])
})

// El que atiende cerraba su turno y no tenía dónde mirarlo: si al día siguiente le preguntan por
// una diferencia, no tenía con qué. Ve LOS SUYOS — el filtro es del backend, no de la pantalla.
test('el dispensador ve los cierres que hizo', async ({ page }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'dispensador')
  await page.goto('/mostrador')

  // En pantalla no hay "turnos": se abre y se cierra la caja, y cada ciclo es un CIERRE.
  await page.locator('.mst__tab', { hasText: 'Cierres' }).click()
  await expect(page.locator('.trn__table tbody tr').first()).toBeVisible()
  // Corregir un conteo ajusta el inventario real: eso es de administración.
  await expect(page.getByRole('button', { name: 'Corregir conteo' })).toHaveCount(0)

  expect(errores, errores.join('\n')).toEqual([])
})

// EL MOSTRADOR EN EL TELÉFONO.
//
// El que atiende está de pie con alguien enfrente: si recibir la mesa y cerrar contando sólo
// existieran en el escritorio, la mitad de su día quedaría fuera de la app que usa. Es la MISMA
// pantalla —no una segunda versión— servida dentro del envoltorio móvil.
test.describe('desde el celular', () => {
  test.use({ viewport: { width: 390, height: 844 } })

  test('el dispensador llega al mostrador desde la barra de abajo y abre la caja', async ({ page }) => {
    const errores = vigilarErrores(page)
    await entrar(page, 'dispensador')
    await page.goto('/m/dispensar')

    // Por la barra de abajo, no por el link de la tarjeta: son dos caminos al mismo lugar y hay
    // que nombrar cuál se está probando (`getByRole` con el nombre suelto matchea los dos y el
    // test moría con "strict mode violation", no con un fallo de la app).
    await page.locator('.msh__tab', { hasText: 'Mostrador' }).click()
    await expect(page).toHaveURL(/\/m\/mostrador/)

    // QUIEN ATIENDE TIENE SU PROPIA PANTALLA (`MMostradorView`), no la tabla de escritorio:
    // parado con alguien enfrente, siete renglones por frasco son cien renglones de scroll para
    // contestar "¿tenés Northern?". Una línea por producto —qué es y cuánto hay— y el resto a un
    // toque. (Esta prueba afirmaba la tabla de escritorio y quedó roja cuando se partió la
    // pantalla por rol: el commit que la partió no la tocó.)
    await expect(page.locator('.tmo__table')).toHaveCount(0)
    // La mesa quedó con los 295 g que dejó el cierre anterior: es un estado permanente, sigue
    // ahí aunque la caja esté cerrada.
    await expect(page.locator('.mmo__card-cant').first()).toContainText('295')

    // Abre la caja contando lo que encuentra.
    await page.click('.mmo__btn')
    await expect(page.locator('.cnt__title')).toHaveText('Abrir caja')
    await page.locator('.cnt__cant .cnt__input').first().fill('295')
    await page.locator('.cnt__input--plata').first().fill('20000')
    await page.locator('.cnt__acc .cnt__btn--primary').click()

    // El estado de la caja, en SU pantalla: arriba de todo y con la acción a ancho completo.
    await expect(page.locator('.mmo__caja-estado')).toHaveText(/Caja abierta/, { timeout: 15_000 })
    await expect(page.locator('.mmo__btn')).toHaveText(/Cerrar caja/)

    expect(errores, errores.join('\n')).toEqual([])
  })
})
