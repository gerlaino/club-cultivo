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
  // Un cambio de mesa sin motivo es un número que aparece: no se puede guardar.
  await expect(page.locator('.mst__guardar .mst__btn')).toBeDisabled()
  await page.fill('.mst__guardar .mst__input', 'carga del lunes')
  await page.click('.mst__guardar .mst__btn')
  await expect(page.locator('.tmo__pie')).toHaveCount(0, { timeout: 15_000 })
  await expect(page.locator('.tmo__table tbody tr').first().locator('.tmo__input')).toHaveValue('300')

  // ── 2. Quien atiende abre la caja contando ─────────────────────────────────
  await entrar(page, 'dispensador')
  await page.goto('/mostrador')
  // Él ve la mesa, pero no la edita: nunca elige qué hay.
  await expect(page.locator('.tmo__mesa').first()).toHaveText('300')
  await expect(page.locator('.mst__estado')).toHaveText(/Cerrado/)
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

  await expect(page.locator('.mst__estado')).toHaveText(/Abierto/, { timeout: 15_000 })
  // La mesa pasa a tener lo que contó, y queda escrito qué pasó.
  await expect(page.locator('.tmo__mesa').first()).toHaveText('297')
  await expect(page.locator('.mst__aviso')).toContainText('contó 297')

  // ── 3. Cierra contando, y ve la comparación ────────────────────────────────
  await page.click('.mst__turno-acc .mst__btn')          // Cerrar caja
  await expect(page.locator('.cnt__comparacion')).toHaveCount(0)
  await page.locator('.cnt__cant .cnt__input').first().fill('295')
  await page.locator('.cnt__input--plata').first().fill('20000')
  await expect(page.locator('.cnt__comparacion')).toContainText('−2')
  await page.locator('.cnt__acc .cnt__btn--primary').click()

  await expect(page.locator('.mst__estado')).toHaveText(/Cerrado/, { timeout: 15_000 })
  // Y la mesa sigue teniendo lo que quedó: el producto está físicamente ahí aunque nadie atienda.
  await expect(page.locator('.tmo__mesa').first()).toHaveText('295')

  expect(errores, errores.join('\n')).toEqual([])
})

test('el admin ve la merma del turno que cerró', async ({ page }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'admin')
  await page.goto('/mostrador')

  await page.locator('.mst__tab', { hasText: 'Merma' }).click()
  await expect(page.locator('.mrm__kpi').first()).toBeVisible()
  await expect(page.getByText('Por producto')).toBeVisible()
  await expect(page.getByText('Turno por turno')).toBeVisible()
  await expect(page.locator('tbody').first()).toContainText('E2E Kush')
  // La lista de trabajo va SEPARADA del análisis: es lo que se termina, no lo que se consulta.
  await expect(page.getByRole('heading', { name: 'Cómo viene' })).toBeVisible()

  expect(errores, errores.join('\n')).toEqual([])
})

// El que atiende cerraba su turno y no tenía dónde mirarlo: si al día siguiente le preguntan por
// una diferencia, no tenía con qué. Ve LOS SUYOS — el filtro es del backend, no de la pantalla.
test('el dispensador ve sus turnos cerrados', async ({ page }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'dispensador')
  await page.goto('/mostrador')

  await page.locator('.mst__tab', { hasText: 'Turnos' }).click()
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

    await page.getByRole('link', { name: 'Mostrador' }).click()
    await expect(page).toHaveURL(/\/m\/mostrador/)

    // La mesa quedó con los 295 g que dejó el turno anterior: es un estado permanente, sigue
    // ahí aunque la caja esté cerrada.
    await expect(page.locator('.tmo__mesa').first()).toHaveText('295')
    // Y se lee como tarjetas, no con scroll horizontal: se usa parado frente a alguien.
    await expect(page.locator('.tmo__table thead')).toBeHidden()

    // Abre la caja contando lo que encuentra.
    await page.click('.mst__turno-acc .mst__btn')
    await expect(page.locator('.cnt__title')).toHaveText('Abrir caja')
    await page.locator('.cnt__cant .cnt__input').first().fill('295')
    await page.locator('.cnt__input--plata').first().fill('20000')
    await page.locator('.cnt__acc .cnt__btn--primary').click()

    await expect(page.locator('.mst__estado')).toHaveText(/Abierto/, { timeout: 15_000 })
    await expect(page.getByRole('button', { name: 'Cerrar caja' })).toBeVisible()

    expect(errores, errores.join('\n')).toEqual([])
  })
})
