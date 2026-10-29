// EL BUSCADOR ABRE LO QUE ELEGISTE, AUNQUE YA ESTÉS EN OTRA FICHA (29-oct-2026, Javi: «cuando
// clickeás en el paciente no te lleva al paciente»). Desde la ficha de un paciente, elegir otro en
// el buscador cambiaba la dirección y la pantalla seguía mostrando al primero: la ficha lee el id
// una sola vez y Vue la reusaba. `App.vue` (`claveVista`) la vuelve a montar cuando cambia el id.
//
// AC: estando en la ficha de Paciente0, buscar a Paciente1 y elegirlo muestra a Paciente1.
import { test, expect } from '@playwright/test'
import { entrar, sembrar, vigilarErrores, API } from './helpers.js'

test.beforeAll(() => sembrar('seed'))

test('desde la ficha de un paciente, el buscador abre a otro', async ({ page }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'admin')

  const pacientes = await page.evaluate(async (base) => {
    const r = await fetch(`${base}/buscar?q=E2E`, { credentials: 'include' })
    return (await r.json()).resultados?.pacientes || []
  }, API)
  const a = pacientes.find(p => p.titulo.includes('Paciente0'))
  const b = pacientes.find(p => p.titulo.includes('Paciente1'))
  expect(a && b, 'el seed trae Paciente0 y Paciente1').toBeTruthy()

  await page.goto(a.ruta)
  await expect(page.locator('h1').first()).toContainText('Paciente0')

  await page.keyboard.press('Control+k')
  await page.locator('[data-testid="buscador-global"] input').fill('Paciente1')
  await page.locator('.bg__item', { hasText: 'Paciente1' }).first().click()

  await expect(page).toHaveURL(new RegExp(`${b.ruta}$`))
  await expect(page.locator('h1').first()).toContainText('Paciente1')
  expect(errores).toEqual([])
})
