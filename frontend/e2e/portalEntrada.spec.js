import { test, expect } from '@playwright/test'
import { entrar, vigilarErrores, sembrar, API } from './helpers.js'

// LA ENTRADA AL PORTAL DEL PACIENTE, DE PUNTA A PUNTA (27-oct-2026).
//
// El camino entero, con las dos personas: administración lo invita desde la ficha y ve el link;
// el paciente abre el link en SU teléfono (otro navegador, sin la sesión del admin), pone su DNI,
// elige su clave y queda adentro. Después vuelve a entrar con DNI y clave. El link no sirve dos
// veces, y la ficha dice que lo activó.
//
// Arranca de `e2e:portal`: el portal de la org e2e contratado y abierto, Paciente2 (DNI 90000002)
// sin cuenta ni links.
test.describe.configure({ mode: 'serial' })

test.beforeAll(() => sembrar('seed', 'portal'))

const DNI = '90000002'
const CLAVE = 'clave-de-prueba-e2e'

test('el admin invita, el paciente activa con su DNI y después entra con DNI y clave', async ({ page, browser }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'admin')

  // ── 1. Administración lo invita desde la ficha ────────────────────────────
  const id = await page.evaluate(async ([base, dni]) => {
    const lista = await (await fetch(`${base}/pacientes?query=${dni}`, { credentials: 'include' })).json()
    return (lista.data ?? lista.pacientes ?? []).find((p) => p.dni === dni)?.id
  }, [API, DNI])
  await page.goto(`/pacientes/${id}`)
  // La solapa del portal vive en «Más» (aparece cuando la ficha confirma que el módulo está).
  await page.getByRole('button', { name: /Más/ }).click()
  await page.getByText('Acceso al portal', { exact: true }).click()
  await expect(page.locator('[data-testid="portal-estado"]')).toHaveText('Sin invitar', { timeout: 15_000 })
  await page.locator('[data-testid="portal-invitar"]').click()

  const link = page.locator('[data-testid="link-portal"]')
  await expect(link).toContainText('/portal/entrar/')
  const url = new URL((await link.textContent()).trim())
  // El botón de WhatsApp lleva el mensaje con el link adentro.
  const wa = await page.locator('[data-testid="link-portal-whatsapp"]').getAttribute('href')
  expect(decodeURIComponent(wa)).toContain(url.pathname)

  // ── 2. El paciente abre el link en su teléfono ────────────────────────────
  const telefono = await browser.newContext({ viewport: { width: 390, height: 844 } })
  const pac = await telefono.newPage()
  const erroresPac = vigilarErrores(pac)
  await pac.goto(url.pathname)
  await expect(pac.getByRole('heading', { name: 'Hola, Paciente2' })).toBeVisible({ timeout: 15_000 })

  // Con otro DNI, no.
  await pac.fill('#pa-dni', '11111111')
  await pac.fill('#pa-clave', CLAVE)
  await pac.fill('#pa-clave2', CLAVE)
  await pac.locator('button[type="submit"]').click()
  await expect(pac.locator('.hb-error')).toContainText('no es el de este link')

  // Con el suyo, elige la clave y queda adentro.
  await pac.fill('#pa-dni', DNI)
  await pac.locator('button[type="submit"]').click()
  await pac.waitForURL((u) => u.pathname === '/portal', { timeout: 20_000 })

  // ── 3. Vuelve a entrar con DNI y clave ────────────────────────────────────
  await telefono.clearCookies()
  await pac.goto('/paciente')
  await pac.fill('#pe-dni', DNI)
  await pac.fill('#pe-clave', 'otra-clave-cualquiera')
  await pac.locator('button[type="submit"]').click()
  await expect(pac.locator('.hb-error')).toContainText('no son correctos')

  await pac.fill('#pe-clave', CLAVE)
  await pac.locator('button[type="submit"]').click()
  await pac.waitForURL((u) => u.pathname === '/portal', { timeout: 20_000 })

  // ── 3b. Mis dispensas: el detalle con la trazabilidad del lote ────────────
  await pac.goto('/portal/historial')
  await pac.getByRole('link', { name: 'Ver detalle' }).first().click()
  await expect(pac.getByText('Trazabilidad del lote')).toBeVisible({ timeout: 15_000 })
  await expect(pac.locator('.pdv__mono').first()).toHaveText('L-E2E-001')
  await expect(pac.locator('.pdv__etapa b')).toContainText(['Floración', 'Envasado', 'Te lo entregaron'])
  await expect(pac.getByText('Laboratorio E2E')).toBeVisible()
  await pac.screenshot({ path: test.info().outputPath('detalle-dispensa.png'), fullPage: true })

  // ── 4. El link ya no sirve ────────────────────────────────────────────────
  await pac.goto(url.pathname)
  await expect(pac.getByRole('heading', { name: 'Este link no sirve' })).toBeVisible({ timeout: 15_000 })
  await expect(pac.locator('a[href="/paciente"]')).toBeVisible()

  // ── 5. La ficha dice que lo activó ────────────────────────────────────────
  await page.reload()
  await page.getByRole('button', { name: /Más/ }).click()
  await page.getByText('Acceso al portal', { exact: true }).click()
  await expect(page.locator('[data-testid="portal-estado"]')).toHaveText('Activó su portal', { timeout: 15_000 })

  expect(errores, errores.join('\n')).toEqual([])
  // El 422 del DNI equivocado, el 401 de la clave equivocada y el 410 del link usado son parte de la prueba (el navegador
  // los anota como «Failed to load resource»); cualquier otro error de la consola, no.
  const reales = erroresPac.filter((e) => !/status of (401|410|422)/.test(e))
  expect(reales, reales.join('\n')).toEqual([])
  await telefono.close()
})
