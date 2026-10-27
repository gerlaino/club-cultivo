import { test, expect } from '@playwright/test'
import { entrar, vigilarErrores, sembrar, API, num } from './helpers.js'

// UNA DISPENSA CON COBRO, DE PUNTA A PUNTA (pendiente desde el 21-oct-2026).
//
// Lo que tiene que pasar cuando la dispensadora le entrega 10 g a un paciente que paga una parte
// en efectivo y deja el resto a cuenta:
//   - la mesa baja lo que se llevó (lo trazable sale SÓLO por dispensación);
//   - el efectivo cae en la caja del mostrador: el cierre espera el fondo MÁS lo cobrado;
//   - lo que no pagó queda como deuda en su cuenta corriente, y NO entra en el arqueo.
//
// Arranca de `e2e:caja_abierta`: 300 g de flor ($1.000/g) sobre la mesa y la caja abierta por
// Dana con $20.000. Abrir contando ya lo prueba `mostrador.spec`.
test.describe.configure({ mode: 'serial' })

test.beforeAll(() => sembrar('seed', 'caja_abierta'))

test('dispensa 10 g, cobra $6.000 en efectivo y deja $4.000 a cuenta', async ({ page }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'dispensador')

  // ── 1. Elige al paciente ───────────────────────────────────────────────────
  await page.goto('/historial')
  await page.click('.hd__btn-nueva')
  await page.fill('.hd__buscar-search', '90000001')
  await page.locator('.hd__buscar-item', { hasText: 'Paciente1' }).click()

  // ── 2. Qué se lleva: 10 g de la flor que está sobre la mesa ────────────────
  // El carrito del que atiende ofrece SÓLO lo de la mesa: el preroll del depósito no aparece.
  const filas = page.locator('.mnd__tr')
  await expect(filas.filter({ hasText: 'Flor seca' })).toHaveCount(1, { timeout: 15_000 })
  await expect(filas.filter({ hasText: 'Preroll' })).toHaveCount(0)
  await filas.filter({ hasText: 'Flor seca' }).click()
  await page.locator('input[type="number"].mnd__input--with-suffix').first().fill('10')
  await page.click('.mnd__add-item')
  await expect(page.locator('.mnd__barra-total')).toContainText('1')

  // ── 3. Cuánto sale: 10 g × $1.000 ──────────────────────────────────────────
  await page.click('.mnd__barra-seguir')            // Cuánto sale
  await expect(page.locator('.mnd__barra-total em')).toHaveText(/10\.000/)

  // ── 4. Cómo paga: efectivo, entrega $6.000 ─────────────────────────────────
  await page.click('.mnd__barra-seguir')            // Cómo paga
  await expect(page.locator('select.mnd__input').filter({ has: page.locator('option[value="efectivo"]') }).first()).toHaveValue('efectivo')
  // Por su etiqueta: los `.mnd__field` se anidan y el que contiene «Paga con» trae también el
  // campo del descuento.
  await page.locator('label.mnd__label', { hasText: 'Paga con' }).locator('xpath=..').locator('input').fill('6000')
  // Lo que falta se dice ANTES de confirmar: es la diferencia entre una decisión y una sorpresa.
  await expect(page.locator('.mnd__pagos-resto')).toContainText('Faltan')
  await expect(page.locator('.mnd__pagos-resto')).toContainText('4.000')
  await expect(page.locator('.mnd__pagos-resto')).toContainText('cuenta corriente')

  // ── 5. Confirma mirando el resumen ─────────────────────────────────────────
  await page.click('.mnd__barra-seguir')            // Confirmar dispensa
  const resumen = page.locator('.rdm')
  await expect(resumen.locator('dd.rdm__total')).toHaveText(/10\.000/)
  await expect(resumen.locator('.rdm__pagos')).toContainText('6.000')
  await expect(resumen.locator('.rdm__pagos')).toContainText('4.000')
  await resumen.locator('.rdm__btn--ok').click()
  await expect(page.locator('.rdm')).toHaveCount(0, { timeout: 15_000 })
  await expect(page.locator('.mnd__overlay')).toHaveCount(0, { timeout: 15_000 })

  // ── 6. La deuda quedó en su cuenta corriente ───────────────────────────────
  const saldo = await page.evaluate(async (base) => {
    // La lista no trae la cuenta corriente: el saldo está en la ficha.
    const lista = await (await fetch(`${base}/pacientes?query=90000001`, { credentials: 'include' })).json()
    const id = (lista.data ?? lista.pacientes ?? []).find(p => p.dni === '90000001')?.id
    const ficha = await (await fetch(`${base}/pacientes/${id}`, { credentials: 'include' })).json()
    return (ficha.data ?? ficha).saldo_cc
  }, API)
  expect(Number(saldo)).toBe(-4000)

  // ── 7. La mesa bajó lo que se llevó ────────────────────────────────────────
  await page.goto('/mostrador')
  await expect(page.locator('.tmo__mesa').first()).toHaveText('290', { timeout: 15_000 })

  // ── 8. Cierra: la caja espera el fondo MÁS lo cobrado en efectivo, no lo que quedó a cuenta ──
  await page.click('.mst__turno-acc .mst__btn')     // Cerrar caja
  await expect(page.locator('.cnt__esperado-plata')).toBeVisible()
  expect(num(await page.locator('.cnt__esperado-plata').textContent())).toBe(26000)
  await expect(page.locator('.cnt__input--plata').first()).toHaveValue('26000')
  await page.locator('.cnt__cant .cnt__input').first().fill('290')
  await page.locator('.cnt__acc .cnt__btn--primary').click()
  await expect(page.locator('.mst__estado')).toHaveText(/Caja cerrada/, { timeout: 15_000 })
  await expect(page.locator('.tmo__mesa').first()).toHaveText('290')

  expect(errores, errores.join('\n')).toEqual([])
})
