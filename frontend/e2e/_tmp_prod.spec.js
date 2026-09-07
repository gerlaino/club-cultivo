import { test } from '@playwright/test'

// Perfil limpio contra PRODUCCIÓN, como una PWA recién instalada.
test.use({ baseURL: 'https://cultivo-staging-api.onrender.com', viewport: { width: 390, height: 844 } })

test('arranque en frío en /m (start_url de la PWA)', async ({ page }) => {
  const errores = []
  page.on('pageerror', e => errores.push('PAGEERROR: ' + e.message.slice(0, 200)))
  page.on('console', m => { if (m.type() === 'error') errores.push('C: ' + m.text().slice(0, 200)) })
  let navs = 0
  page.on('framenavigated', f => { if (f === page.mainFrame()) navs++ })

  await page.goto('/m', { waitUntil: 'load' })
  await page.waitForTimeout(9000)

  const info = await page.evaluate(() => ({
    body: document.body.innerText.slice(0, 120).replace(/\n/g, ' | '),
    appHtml: document.querySelector('#app')?.innerHTML.length ?? -1,
    sw: !!navigator.serviceWorker?.controller,
  }))
  console.log('NAVS ' + navs)
  console.log('INFO ' + JSON.stringify(info))
  errores.slice(0, 8).forEach(e => console.log(e))
  await page.screenshot({ path: '/tmp/claude-1000/-home-gerlaino-Projects-club-cultivo/469aa951-466c-477a-9f64-cd2205889979/scratchpad/prod-frio.png' })
})
