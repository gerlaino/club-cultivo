// «+ → REGAR» ESTANDO YA EN LA FICHA DEL LOTE.
//
// Germán (4-oct-2026), regando su balcón: parado en la ficha del lote, tocó «+ → Regar» y no pasó
// nada. El «+» manda a `/m/lote-m/:id?accion=riego`; si ya estabas ahí cambia sólo la query, Vue
// reusa la pantalla y la ficha leía `?accion=` únicamente al montarse. Desde «Hoy» andaba, por eso
// nadie lo vio: el caso que importa es el segundo riego, desde la ficha.
import { test, expect } from '@playwright/test'
import { entrar, vigilarErrores, sembrar, API } from './helpers.js'

test.beforeAll(() => sembrar('seed'))
test.use({ viewport: { width: 390, height: 844 } })

// El «+» pregunta qué regaste sólo si hay más de una opción; con una, va derecho.
async function regarDesdeElMas (page, codigo) {
  await page.locator('.msh__fab').click()
  // El «+» trae lotes y camas al abrirse: tocar «Regar» antes es elegir sobre una lista vacía.
  await page.waitForLoadState('networkidle')
  await page.locator('button', { hasText: /^\s*Regar\s*$/ }).first().click()
  const opcion = page.locator('.msh__mas-item').filter({ hasText: codigo })
  if (await opcion.count()) await opcion.first().click()
}

test('+ → Regar abre el riego también si ya estás en la ficha del lote', async ({ page }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'cultivador')
  // Cualquier lote en pie de la org (los escenarios de cultivo mueven las fases; no se fija uno).
  const res = await (await page.request.get(`${API}/lotes`)).json()
  const lote = (res.data || res).find(l => ['vegetativo', 'floracion'].includes(l.estado))
  const LOTE = lote.codigo
  await page.goto(`/m/lote-m/${lote.id}`)
  await expect(page.locator('.mlot__hero-codigo')).toHaveText(LOTE)

  // Parado en la ficha, «+ → Regar»: el diario se abre derecho en Riego, de este lote.
  const riego = page.locator('.rls__seccion-header', { hasText: 'Riego' })
  await regarDesdeElMas(page, LOTE)
  await expect(riego).toBeVisible()
  await expect(page.locator('.rls__subtitle')).toContainText(LOTE)
  await expect(page).toHaveURL(new RegExp(`/m/lote-m/${lote.id}$`))

  // Se cierra y otra vez: tiene que volver a abrir (la query ya se había limpiado).
  await page.locator('.rls__close').click()
  await expect(riego).toBeHidden()
  await regarDesdeElMas(page, LOTE)
  await expect(riego).toBeVisible()
  // Y la URL queda limpia: recargar no vuelve a abrir el diario.
  await expect(page).toHaveURL(/\/m\/lote-m\/\d+$/)

  expect(errores).toEqual([])
})
