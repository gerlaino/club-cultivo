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

  // ── 1. El admin carga la mesa ──────────────────────────────────────────────
  await entrar(page, 'admin')
  await page.goto('/mostrador')
  await expect(page.locator('.mst__estado')).toHaveText(/Cerrado/)

  await page.fill('.mst__input--fondo', '50000')
  // La tabla del inventario, con lo que hace falta para decidir: lote, fecha, libre, precio.
  // La cantidad ES la marca — no hay tilde aparte.
  await page.fill('.tst__buscar', 'flor seca')
  await expect(page.locator('.tst__table tbody tr')).toHaveCount(1)
  await page.fill('.tst__table tbody tr .tst__input', '300')
  await expect(page.locator('.tst__pie')).toContainText('300 g')
  await page.click('.mst__acciones .mst__btn--primary')
  await expect(page.locator('.mst__estado')).toHaveText(/Falta recibirlo/)

  // Quien cargó la mesa no se la recibe a sí mismo: dos firmas de la misma persona no son
  // ninguna. Ve lo que dejó y espera.
  await expect(page.getByText('Esperando que lo reciban')).toBeVisible()
  await expect(page.locator('.mst__acciones .mst__btn--primary')).toHaveCount(0)

  // ── 2. El que atiende la recibe, corrigiendo ───────────────────────────────
  await entrar(page, 'dispensador')
  await page.goto('/mostrador')
  await expect(page.getByText(/dejó esto sobre la mesa/)).toBeVisible()
  await expect(page.locator('.mst__input--cant')).toHaveValue('300')

  await page.fill('.mst__input--cant', '297')
  await expect(page.locator('.mst__dif')).toHaveText('-3 g')
  await page.locator('.mst__campo--motivo .mst__input').first().fill('faltaban 3 g')
  await page.click('.mst__acciones .mst__btn--primary')
  await expect(page.locator('.mst__estado')).toHaveText(/Abierto/)

  // La corrección quedó: la mesa arranca con lo que él contó, no con lo que declaró el admin.
  await expect(page.locator('.mst__mesa')).toHaveText('297')

  // ── 3. Cuenta UN producto sin cerrar: con quince frascos, cerrar y reabrir son veinte
  //       minutos, y el control que cuesta eso no se hace ─────────────────────
  await page.locator('tbody tr').first().locator('.mst__btn--mini').nth(2).click()
  await expect(page.locator('.mst__modal')).toContainText('Contar')
  await expect(page.locator('.mst__modal')).not.toContainText('Tendría que haber')
  await page.locator('.mst__modal .mst__input').first().fill('295')
  await expect(page.locator('.mst__dif-caja')).toHaveText('Faltan 2 g')
  await page.locator('.mst__modal .mst__campo--motivo .mst__input').fill('se cayó al piso')
  await page.locator('.mst__modal-acc .mst__btn--primary').click()
  // El conteo corre el esperado: a la noche no se cuenta dos veces la misma diferencia.
  await expect(page.locator('.mst__mesa')).toHaveText('295', { timeout: 15_000 })

  // ── 4. Cierra contando, y el esperado no se ve hasta que escribe ───────────
  await page.click('.mst__turno .mst__btn--primary')
  await expect(page.locator('.mst__modal')).toBeVisible()

  // Nadie pesa 297 g teniendo el 297 delante: con el número a la vista el arqueo es teatro.
  await expect(page.locator('.mst__conteo-row').first()).not.toContainText('tendría que haber')
  await expect(page.locator('.mst__caja')).not.toContainText('Tendría que haber')

  await page.locator('.mst__conteo-row').first().locator('.mst__input--cant').fill('295')
  await expect(page.locator('.mst__conteo-row').first()).toContainText('tendría que haber 295 g')
  await expect(page.locator('.mst__modal .mst__dif').first()).toHaveText('cuadra')
  await page.locator('.mst__caja .mst__input').first().fill('50000')
  await expect(page.locator('.mst__dif-caja')).toHaveText('Cuadra')
  await page.click('.mst__modal-acc .mst__btn--primary')

  await expect(page.locator('.mst__estado')).toHaveText(/Cerrado/, { timeout: 15_000 })

  // ── 5. Mañana hereda lo de anoche ──────────────────────────────────────────
  const heredada = page.locator('.tst__table tbody tr').first()
  await expect(heredada.locator('.tst__input')).toHaveValue('295')
  await expect(heredada).toContainText('venía de anoche')
  await expect(page.getByText(/quedaron \$50\.000 en el cajón anoche/)).toBeVisible()

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
