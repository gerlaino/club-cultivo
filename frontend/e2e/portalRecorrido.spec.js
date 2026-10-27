import { test, expect } from '@playwright/test'
import { entrar, vigilarErrores, sembrar, API } from './helpers.js'

// EL PORTAL DEL PACIENTE, RECORRIDO (27-oct-2026): lo que se sumó además de la entrada y el chat.
//
//   - Mi salud: el REPROCANN por vencer; sube la constancia y queda en revisión. Administración la
//     ve en la ficha, la aprueba con la fecha nueva, y al paciente se le actualiza solo.
//   - Catálogo: la flor de la mesa, con precio y «Hay», y el enlace a su genética.
//   - Eventos: «Asistiré», y administración ve que va.
//
// Arranca de `e2e:portal` (Paciente2 sin cuenta: la prueba lo activa por la API).
test.describe.configure({ mode: 'serial' })

test.beforeAll(() => sembrar('seed', 'portal'))

const DNI = '90000002'
const CLAVE = 'clave-de-prueba-recorrido'

test('mi salud, catálogo y eventos, con lo que ve administración', async ({ page, browser }) => {
  test.setTimeout(120_000)
  const errores = vigilarErrores(page)
  await entrar(page, 'admin')

  const { token, id } = await page.evaluate(async ([base, dni]) => {
    const lista = await (await fetch(`${base}/pacientes?query=${dni}`, { credentials: 'include' })).json()
    const pid = (lista.data ?? lista.pacientes ?? []).find((p) => p.dni === dni)?.id
    const r = await (await fetch(`${base}/pacientes/${pid}/acceso/invitar`, { method: 'POST', credentials: 'include' })).json()
    return { token: r.link.url.split('/').pop(), id: pid }
  }, [API, DNI])

  const tel = await browser.newContext({ viewport: { width: 390, height: 844 } })
  const pac = await tel.newPage()
  const erroresPac = vigilarErrores(pac)
  const act = await pac.request.post(`${API}/portal_acceso/links/${token}/activar`, { data: { dni: DNI, password: CLAVE, password_confirmation: CLAVE } })
  expect(act.ok()).toBeTruthy()

  // ── Inicio: la credencial avisa y lleva a subir la renovación ────────────
  await pac.goto('/portal')
  await pac.getByRole('link', { name: 'Subir la renovación del REPROCANN' }).click()
  await expect(pac.locator('[data-testid="reprocann-estado"]')).toHaveText('Por vencer', { timeout: 15_000 })

  // ── Sube la constancia ───────────────────────────────────────────────────
  await pac.locator('[data-testid="subir-renovacion"] input[type="file"]').setInputFiles({
    name: 'constancia.pdf', mimeType: 'application/pdf', buffer: Buffer.from('%PDF-1.4 constancia e2e'),
  })
  await expect(pac.locator('[data-testid="reprocann-estado"]')).toHaveText('Renovación en revisión', { timeout: 15_000 })

  // ── Administración la aprueba desde la ficha ─────────────────────────────
  await page.goto(`/pacientes/${id}?tab=reprocann`)
  const card = page.locator('[data-testid="renovacion-portal"]')
  await expect(card).toContainText('constancia.pdf', { timeout: 15_000 })
  const enUnAnio = new Date(Date.now() + 365 * 86400000).toISOString().slice(0, 10)
  await card.locator('[data-testid="renovacion-vencimiento"]').fill(enUnAnio)
  await card.locator('[data-testid="renovacion-aprobar"]').click()
  await expect(card).toHaveCount(0, { timeout: 15_000 })

  // ── Al paciente se le actualiza solo ─────────────────────────────────────
  await expect(pac.locator('[data-testid="reprocann-estado"]')).toHaveText('Vigente', { timeout: 15_000 })
  await expect(pac.getByText('Tu organización aprobó la renovación')).toBeVisible()

  // ── Catálogo ─────────────────────────────────────────────────────────────
  await pac.goto('/portal/catalogo')
  const producto = pac.locator('[data-testid="producto"]').first()
  await expect(producto).toContainText('E2E Kush', { timeout: 15_000 })
  await expect(producto).toContainText('Hay')
  await pac.screenshot({ path: test.info().outputPath('catalogo.png'), fullPage: true })

  // ── Eventos: Asistiré ────────────────────────────────────────────────────
  await pac.goto('/portal/eventos')
  await pac.getByText('Taller e2e').click()
  await pac.locator('[data-testid="asistire"]').click()
  await expect(pac.locator('[data-testid="asistire"]')).toHaveText('Asistiré ✓')

  const asistentes = await page.evaluate(async (base) => {
    const evs = await (await fetch(`${base}/eventos`, { credentials: 'include' })).json()
    return (evs.data || []).find((e) => e.titulo === 'Taller e2e')?.asistentes
  }, API)
  expect(asistentes).toBe(1)

  expect(errores, errores.join('\n')).toEqual([])
  expect(erroresPac, erroresPac.join('\n')).toEqual([])
  await tel.close()
})
