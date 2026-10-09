// LA CARPA DE LA CUENTA DE AUTOCULTIVO DE LAS GRABACIONES, armada con la app (fuera de cámara),
// como lo haría quien recién se registra: dos espacios y tres plantas que ya vienen creciendo, con
// los días de su genética cargados (sin días no hay «próximos pasos»). Si ya está armada, no hace
// nada. La llama `grabar.mjs` antes de los flujos de autocultivo.
export const AUTOCULTIVO = 'autocultivo@demo-video.example.com'

const PLANTAS = [
  { gen: 'Gorilla Glue', auto: false, diasGen: 63, cuantas: 2, fase: 'Floreciendo', donde: 'Carpa grande', dias: 23 },
  { gen: 'Northern Auto', auto: true, diasGen: 77, cuantas: 1, fase: 'En maceta', donde: 'Carpa chica', dias: 19 },
]

export async function armarBaseAutocultivo (navegador, { BASE, CLAVE }) {
  const ctx = await navegador.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true })
  const p = await ctx.newPage()
  await p.goto(BASE + '/login'); await p.waitForSelector('input[type="password"]')
  await p.fill('input[type="email"]', AUTOCULTIVO); await p.fill('input[type="password"]', CLAVE)
  await p.click('button[type="submit"]'); await p.waitForURL(u => !u.pathname.includes('/login'))
  // Espera a que «Mi cultivo» termine de cargar: preguntar «¿ya existe?» antes duplicaba plantas.
  const ir = async () => {
    await p.goto(BASE + '/m/personal/cultivo')
    await p.waitForSelector('.mmc__espacio-cab, .mmc__btn', { timeout: 20000 })
    await p.waitForTimeout(600)
  }
  const opcion = (sel, texto) => sel.evaluate((s, t) => [...s.options].find(o => o.textContent.includes(t))?.value, texto)

  await ir()
  const espacios = [['Carpa grande', 'Floración'], ['Carpa chica', 'Vegetativo']]
  for (const [nombre, fase] of espacios) {
    if (await p.locator('.mmc__espacio-cab', { hasText: nombre }).count()) continue
    const primero = p.locator('.mmc__btn', { hasText: 'Crear mi primer espacio' })
    if (await primero.count()) await primero.click()
    else { await p.click('.msh__fab'); await p.waitForTimeout(600); await p.click('.mag__item:has-text("Crear espacio")') }
    await p.waitForTimeout(700)
    await p.fill('.mcr__input >> nth=0', nombre)
    await p.click(`.mcr__kind-btn:has-text("${fase}")`)
    await p.click('.mcr__btn-primary'); await p.waitForTimeout(1600)
    await ir()
  }

  for (const pl of PLANTAS) {
    await ir()
    if (await p.locator('.mmc__planta', { hasText: pl.gen }).count()) continue
    await p.click('.msh__fab'); await p.waitForTimeout(600); await p.click('.mag__item:has-text("Nueva planta")'); await p.waitForTimeout(800)
    const genSel = p.locator('.np__label', { hasText: 'Genética' }).locator('xpath=following::select[1]')
    const gv = await opcion(genSel, pl.gen)
    if (gv) await genSel.selectOption(gv)
    else {
      await p.click('.np__link:has-text("Genética nueva")'); await p.waitForTimeout(400)
      await p.fill('input[placeholder="Ej: Fruti Punchi"]', pl.gen)
      await p.click(`.np__opcion:has-text("${pl.auto ? 'Automática' : 'Fotoperiódica'}")`)
      await p.locator('.np__label', { hasText: 'Días' }).locator('xpath=following::input[1]').fill(String(pl.diasGen))
      await p.click('.np__btn:has-text("Guardar y seguir")'); await p.waitForTimeout(1000)
    }
    for (let i = 1; i < pl.cuantas; i++) { await p.locator('.np__step', { hasText: '+' }).click(); await p.waitForTimeout(120) }
    await p.click(`.np__opcion:has-text("${pl.fase}")`); await p.waitForTimeout(400)
    const donde = p.locator('.np__label', { hasText: 'Dónde' }).locator('xpath=following::select[1]')
    await donde.selectOption(await opcion(donde, pl.donde))
    await p.locator('.np__label', { hasText: 'Días que lleva' }).locator('xpath=following::input[1]').fill(String(pl.dias))
    await p.click('.np__btn:has-text("Agregar")'); await p.waitForTimeout(1600)
  }
  await ctx.close()
}
