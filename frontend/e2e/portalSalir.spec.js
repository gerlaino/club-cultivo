// EL PACIENTE PUEDE CERRAR SESIÓN (30-oct-2026, Germán: «no está por ningún lado»). En la compu la
// única salida era el pie, debajo de todo el inicio, y el ícono de cuenta se escondía en esa
// pantalla. AC: en la compu «Cerrar sesión» se ve arriba sin bajar; en el teléfono, por el ícono de
// «Mi cuenta». Al salir vuelve a la puerta de su organización y /portal ya no lo deja entrar.
import { test, expect } from '@playwright/test'
import { entrar, sembrar, API } from './helpers.js'

test.beforeAll(() => sembrar('seed', 'portal'))

const DNI = '90000002'
const CLAVE = 'clave-de-prueba-e2e'

async function activarPortal(page) {
  await entrar(page, 'admin')
  const id = await page.evaluate(async ([base, dni]) => {
    const l = await (await fetch(`${base}/pacientes?query=${dni}`, { credentials: 'include' })).json()
    return (l.data ?? l.pacientes ?? []).find((p) => p.dni === dni)?.id
  }, [API, DNI])
  await page.goto(`/pacientes/${id}`)
  await page.getByText('Datos y contacto', { exact: true }).first().click()
  await page.getByText('Acceso al portal', { exact: true }).click()
  await page.locator('[data-testid="portal-invitar"]').click()
  return new URL((await page.locator('[data-testid="link-portal"]').textContent()).trim()).pathname
}

async function quedoAfuera(pac) {
  await pac.waitForURL((u) => u.pathname.startsWith('/paciente'), { timeout: 20_000 })
  await pac.goto('/portal')
  await pac.waitForURL((u) => u.pathname.startsWith('/paciente'), { timeout: 20_000 })
}

test('el paciente cierra sesión desde la compu y desde el teléfono', async ({ page, browser }) => {
  const link = await activarPortal(page)

  // Teléfono: activa con el link y sale por «Mi cuenta».
  const tel = await (await browser.newContext({ viewport: { width: 390, height: 844 } })).newPage()
  await tel.goto(link)
  await tel.fill('#pa-dni', DNI); await tel.fill('#pa-clave', CLAVE); await tel.fill('#pa-clave2', CLAVE)
  await tel.locator('button[type="submit"]').click()
  await tel.waitForURL((u) => u.pathname === '/portal', { timeout: 20_000 })
  await tel.locator('[data-testid="portal-mi-cuenta"]').click()
  await tel.locator('[data-testid="cuenta-salir"]').click()
  await quedoAfuera(tel)

  // Compu: el botón está en la barra de arriba, a la vista sin bajar.
  const pc = await (await browser.newContext({ viewport: { width: 1440, height: 900 } })).newPage()
  await pc.goto('/paciente')
  await pc.fill('#pe-dni', DNI); await pc.fill('#pe-clave', CLAVE)
  await pc.locator('button[type="submit"]').click()
  await pc.waitForURL((u) => u.pathname === '/portal', { timeout: 20_000 })
  const salir = pc.locator('[data-testid="portal-salir"]')
  await expect(salir).toBeInViewport()
  await pc.screenshot({ path: test.info().outputPath('barra-compu.png') })
  await salir.click()
  await quedoAfuera(pc)
})
