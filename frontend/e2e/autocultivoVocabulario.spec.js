// EL AUTOCULTIVO NO HABLA COMO UNA ORGANIZACIÓN.
//
// Germán (9 y 11-oct-2026): en autocultivo no hay lotes, salas ni sedes: hay plantas de una
// genética y espacios de cultivo. Las pantallas se comparten con las organizaciones, así que cada
// pantalla nueva arrancaba diciendo «lote» hasta que alguien la veía (pasó tres veces en una
// semana). Esta prueba recorre lo que abre una persona de autocultivo, en la compu y en el
// teléfono, y falla si aparece una palabra de organización o el código de un lote.
import { test, expect } from '@playwright/test'
import { entrar, vigilarErrores, sembrar, API } from './helpers.js'

test.beforeAll(() => sembrar('autocultivo'))

const PROHIBIDO = /\b(lotes?|salas?|sedes?|socios?|pacientes?|organizaci[oó]n(es)?)\b/i

// Las ids salen de la API: el seed es idempotente y no fija números.
async function ids (page) {
  const get = async (p) => { const j = await (await page.request.get(`${API}${p}`)).json(); return j.data || j }
  const [lotes, salas, plantas] = await Promise.all([get('/lotes'), get('/salas'), get('/plants')])
  const enVege = lotes.find(l => l.estado === 'vegetativo')
  const cosecha = lotes.find(l => l.estado === 'curado')
  return {
    codigos: lotes.map(l => l.codigo).filter(Boolean),
    sala: salas.find(s => s.nombre === 'Carpa E2E').id,
    lote: enVege.id, cosecha: cosecha.id,
    planta: plantas.find(p => p.lote?.id === enVege.id).id,
  }
}

async function revisar (page, ruta, codigos) {
  await page.goto(ruta)
  await page.waitForLoadState('networkidle').catch(() => {})
  await page.waitForTimeout(800)
  const texto = await page.evaluate(() => document.body.innerText)
  const lineas = texto.split('\n').filter(l => PROHIBIDO.test(l) || codigos.some(c => l.includes(c)))
  expect(lineas, `${ruta} habla como una organización`).toEqual([])
}

test('en la compu', async ({ page }) => {
  const errores = vigilarErrores(page)
  await entrar(page, 'casa')
  const i = await ids(page)
  for (const ruta of ['/', '/mi-cultivo', `/salas/${i.sala}`, `/lotes/${i.lote}`, `/lotes/${i.cosecha}`,
    `/plantas/${i.planta}`, '/tareas', '/admin/stock', '/mis-informes', '/configuracion/club',
    '/configuracion/alertas', '/perfil', '/recetas', '/guia-nutrientes']) {
    await revisar(page, ruta, i.codigos)
  }
  expect(errores).toEqual([])
})

test.describe('en el teléfono', () => {
  test.use({ viewport: { width: 390, height: 844 } })

  test('las pantallas del día', async ({ page }) => {
    const errores = vigilarErrores(page)
    await entrar(page, 'casa')
    const i = await ids(page)
    for (const ruta of ['/m/personal/hoy', '/m/personal/cultivo', `/m/sala-m/${i.sala}`, `/m/lote-m/${i.lote}`,
      `/m/lote-m/${i.cosecha}`, `/m/planta/${i.planta}`, '/m/personal/stock', '/m/personal/gastos',
      '/m/personal/informes', '/m/tareas', '/m/personal/guia']) {
      await revisar(page, ruta, i.codigos)
    }
    expect(errores).toEqual([])
  })
})
