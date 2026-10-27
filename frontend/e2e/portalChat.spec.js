import { test, expect } from '@playwright/test'
import { entrar, vigilarErrores, sembrar, API } from './helpers.js'

// EL CHAT DEL PORTAL, EN VIVO Y DE PUNTA A PUNTA (27-oct-2026).
//
// El paciente escribe desde su portal y a administración le aparece la alerta SIN recargar, con su
// nombre; contesta desde la bandeja y al paciente le llega la respuesta firmada, también en vivo, y
// su mensaje pasa a ✓✓ (leído). Arranca de `e2e:portal`: Paciente2 (DNI 90000002) sin cuenta; la
// prueba lo invita y activa por la API (el camino de la pantalla lo prueba `portalEntrada.spec`).
test.describe.configure({ mode: 'serial' })

test.beforeAll(() => sembrar('seed', 'portal'))

const DNI = '90000002'
const CLAVE = 'clave-de-prueba-chat'

test('el paciente escribe, a administración le llega en vivo, contesta y el paciente lo ve', async ({ page, browser }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'admin')

  // ── Preparación: el paciente con su portal activado ──────────────────────
  const token = await page.evaluate(async ([base, dni]) => {
    const lista = await (await fetch(`${base}/pacientes?query=${dni}`, { credentials: 'include' })).json()
    const id = (lista.data ?? lista.pacientes ?? []).find((p) => p.dni === dni)?.id
    const r = await (await fetch(`${base}/pacientes/${id}/acceso/invitar`, { method: 'POST', credentials: 'include' })).json()
    return r.link.url.split('/').pop()
  }, [API, DNI])

  const telefono = await browser.newContext({ viewport: { width: 390, height: 844 } })
  const pac = await telefono.newPage()
  const erroresPac = vigilarErrores(pac)
  const act = await pac.request.post(`${API}/portal_acceso/links/${token}/activar`,
    { data: { dni: DNI, password: CLAVE, password_confirmation: CLAVE } })
  expect(act.ok()).toBeTruthy()

  // ── Administración, en la bandeja (todavía vacía) ────────────────────────
  await page.goto('/chat-pacientes')
  await expect(page.getByText('No hay mensajes esperando respuesta.')).toBeVisible({ timeout: 15_000 })

  // ── El paciente escribe desde su portal ──────────────────────────────────
  await pac.goto('/portal/mensajes')
  await expect(pac.getByText('Escribile a tu organización')).toBeVisible({ timeout: 15_000 })
  await pac.locator('textarea').fill('Hola! Ya subí la constancia del REPROCANN, ¿está bien?')
  await pac.locator('textarea').press('Enter')
  await expect(pac.locator('[data-testid="msj-mio"]')).toContainText('Ya subí la constancia')

  // ── A administración le aparece la alerta, sin recargar ──────────────────
  const alerta = page.locator('[data-testid="alerta-mensaje"]')
  await expect(alerta).toContainText('Paciente2', { timeout: 15_000 })
  await expect(alerta).toContainText('Ya subí la constancia')
  await alerta.getByRole('button', { name: 'Responder' }).click()

  // ── Abre la conversación y contesta ──────────────────────────────────────
  await expect(page.locator('[data-testid="msj-otro"]')).toContainText('Ya subí la constancia', { timeout: 15_000 })
  await page.locator('.cpv__chat textarea').fill('Hola! Ya la vimos, está todo bien.')
  await page.locator('.cpv__chat textarea').press('Enter')
  await expect(page.locator('[data-testid="msj-mio"]')).toContainText('Ya la vimos')

  // ── Al paciente le llega la respuesta firmada, en vivo, y lo suyo figura leído ──
  const respuesta = pac.locator('[data-testid="msj-otro"]')
  await expect(respuesta).toContainText('Ya la vimos', { timeout: 15_000 })
  await expect(respuesta).toContainText('Ada')
  await expect(pac.locator('[data-testid="msj-mio"] .ch__tilde').first()).toHaveText('✓✓')
  await pac.screenshot({ path: test.info().outputPath('chat-paciente.png') })
  await page.screenshot({ path: test.info().outputPath('chat-admin.png') })

  expect(errores, errores.join('\n')).toEqual([])
  expect(erroresPac, erroresPac.join('\n')).toEqual([])
  await telefono.close()
})
