import { test, expect } from '@playwright/test'
import { entrar, sembrar, API } from './helpers.js'

// EL CARTEL ROJO DE UN INSTANTE (Germán, 27-oct-2026). Después de confirmar una dispensa, la ficha
// recargaba al paciente vaciándolo primero, y durante el viaje del pedido decía «Paciente no
// encontrado.» y rearmaba todas sus solapas. Se mira cada cambio de la página, no una foto al final:
// el cartel duraba un cuarto de segundo.
test.describe.configure({ mode: 'serial' })
test.beforeAll(() => sembrar('seed', 'caja_abierta'))
test('dispensar desde la ficha no muestra «Paciente no encontrado» ni un instante', async ({ page }) => {
  await entrar(page, 'dispensador')
  const id = await page.evaluate(async (base) => {
    const l = await (await fetch(`${base}/pacientes?query=90000001`, { credentials: 'include' })).json()
    return (l.data ?? l.pacientes ?? []).find(p => p.dni === '90000001')?.id
  }, API)
  await page.goto(`/socios/${id}`)
  await page.locator('.dv__btn-primary:visible').first().click()
  await page.evaluate(() => {
    window.__rojo = []
    new MutationObserver(() => {
      document.querySelectorAll('.sd__error').forEach(e => window.__rojo.push(e.textContent))
      if (document.querySelector('.sd__loading')) window.__rojo.push('ruedita')
    }).observe(document.body, { subtree: true, childList: true, characterData: true })
  })
  const filas = page.locator('.mnd__tr')
  await filas.filter({ hasText: 'Flor seca' }).click()
  await page.locator('input[type="number"].mnd__input--with-suffix').first().fill('5')
  await page.click('.mnd__add-item')
  await page.click('.mnd__barra-seguir')
  await page.click('.mnd__barra-seguir')
  await page.locator('label.mnd__label', { hasText: 'Paga con' }).locator('xpath=..').locator('input').fill('5000')
  await page.click('.mnd__barra-seguir')
  await page.locator('.rdm .rdm__btn--ok').click()
  await expect(page.locator('.mnd__overlay')).toHaveCount(0, { timeout: 15000 })
  await page.waitForLoadState('networkidle'); await page.waitForTimeout(1500)
  await page.screenshot({ path: process.env.SHOT })
  expect(await page.evaluate(() => window.__rojo)).toEqual([])
})
