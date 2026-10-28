import { test, expect } from '@playwright/test'
import { entrar, vigilarErrores, sembrar, API } from './helpers.js'

// «RESERVAR» DESDE EL PORTAL (Germán, 28-oct-2026), de punta a punta:
//   - el paciente, en el teléfono, elige de la mesa, retira mañana y pide;
//   - el pedido queda «Esperando confirmación» y ese día ya no se ofrece (una reserva por día);
//   - administración lo ve en «Pedidos del portal» y lo confirma;
//   - al paciente le aparece «Confirmada» sin recargar.
//
// Arranca de `e2e:portal` (Paciente2 sin cuenta: la prueba lo activa por la API).
test.describe.configure({ mode: 'serial' })

test.beforeAll(() => sembrar('seed', 'portal'))

const DNI = '90000002'
const CLAVE = 'clave-de-prueba-reservar'

test('el paciente pide para mañana y administración lo confirma', async ({ page, browser }) => {
  test.setTimeout(120_000)
  const errores = vigilarErrores(page)
  await entrar(page, 'admin')

  const { token } = await page.evaluate(async ([base, dni]) => {
    const lista = await (await fetch(`${base}/pacientes?query=${dni}`, { credentials: 'include' })).json()
    const pid = (lista.data ?? lista.pacientes ?? []).find((p) => p.dni === dni)?.id
    const r = await (await fetch(`${base}/pacientes/${pid}/acceso/invitar`, { method: 'POST', credentials: 'include' })).json()
    return { token: r.link.url.split('/').pop() }
  }, [API, DNI])

  const tel = await browser.newContext({ viewport: { width: 390, height: 844 } })
  const pac = await tel.newPage()
  const erroresPac = vigilarErrores(pac)
  const act = await pac.request.post(`${API}/portal_acceso/links/${token}/activar`, { data: { dni: DNI, password: CLAVE, password_confirmation: CLAVE } })
  expect(act.ok()).toBeTruthy()

  // ── El paciente pide ─────────────────────────────────────────────────────
  await pac.goto('/portal/reservar')
  const producto = pac.locator('[data-testid="producto"]').first()
  await expect(producto).toContainText('E2E Kush', { timeout: 15_000 })
  await producto.locator('[data-testid="cantidad"]').fill('5')
  await pac.getByRole('radio', { name: 'Mañana' }).click()
  await pac.screenshot({ path: test.info().outputPath('reservar-pedido.png'), fullPage: true })
  await pac.locator('[data-testid="pedir"]').click()

  const pedido = pac.locator('[data-testid="pedido"]').first()
  await expect(pedido).toContainText('Esperando confirmación', { timeout: 15_000 })
  await expect(pedido).toContainText('Para mañana')
  // Una por día: mañana ya está tomado, le queda hoy.
  await producto.locator('[data-testid="cantidad"]').fill('2')
  await expect(pac.getByRole('radio', { name: 'Mañana' })).toBeDisabled()
  await expect(pac.getByRole('radio', { name: 'Hoy' })).toHaveAttribute('aria-checked', 'true')
  await producto.locator('[data-testid="cantidad"]').fill('')

  // ── Administración lo confirma ───────────────────────────────────────────
  await page.goto('/reservas?estado=solicitada')
  const fila = page.locator('tr', { hasText: 'Lo pidió desde el portal' })
  await expect(fila).toContainText('E2E Kush', { timeout: 15_000 })
  await page.screenshot({ path: test.info().outputPath('reservas-pedidos.png'), fullPage: true })
  await fila.getByRole('button', { name: 'Confirmar' }).click()
  await expect(page.getByText('Pedido confirmado')).toBeVisible({ timeout: 15_000 })

  // ── Al paciente se le actualiza solo ─────────────────────────────────────
  await expect(pedido).toContainText('Confirmada', { timeout: 15_000 })
  await pac.screenshot({ path: test.info().outputPath('reservar-confirmada.png'), fullPage: true })

  expect(errores, errores.join('\n')).toEqual([])
  expect(erroresPac, erroresPac.join('\n')).toEqual([])
  await tel.close()
})
