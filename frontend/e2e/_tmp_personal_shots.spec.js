import { test } from '@playwright/test'
const OUT = '/tmp/claude-1000/-home-gerlaino-Projects-club-cultivo/3e31b272-68d0-4a3b-9af0-2281a52c73fc/scratchpad/shots'
test('pantallas de escritorio del uso personal', async ({ page }) => {
  await page.goto('/login')
  await page.evaluate(() => { localStorage.clear(); sessionStorage.clear() })
  await page.context().clearCookies()
  await page.goto('/login')
  await page.fill('input[type="email"], input[name="email"]', 'admin@casa_german.com')
  await page.fill('input[type="password"]', 'E2eTest2026!')
  await page.click('button[type="submit"]')
  await page.waitForURL(u => !u.pathname.includes('/login'), { timeout: 20_000 })
  const rutas = process.env.RUTAS ? process.env.RUTAS.split(',') : ['/contabilidad', '/salas', '/lotes', '/admin/stock', '/insumos', '/tareas', '/analitica', '/configuracion/alertas', '/geneticas', '/admin/cosechado', '/plan-trabajo']
  for (const ruta of rutas) {
    await page.goto(ruta)
    await page.waitForLoadState('networkidle').catch(() => {})
    await page.waitForTimeout(900)
    await page.screenshot({ path: `${OUT}/p${ruta.replace(/\//g, '_')}.png`, fullPage: true })
  }
})
