// HUMO POR ROL: cada rol abre cada pantalla que su menú le ofrece, en la compu y en el teléfono.
//
// Paso 4 del congelamiento (20-oct-2026). El recorrido manual de ese día encontró, sin apretar un
// solo botón: la disponibilidad del médico con 404 desde junio, la ficha del paciente pidiendo
// algo que el backend le niega al médico, barras de arriba que se pisaban en el teléfono, una
// ficha que se salía de la pantalla y links que llevaban a «No tenés acceso». Ninguno lo veía un
// test: los specs prueban reglas, no que una pantalla abra. Esto lo prueba en cada push.
//
// Sólo NAVEGA: no aprieta nada, así que no cambia datos. Falla si una pantalla:
//   · tira un error de JavaScript;
//   · recibe un 4xx/5xx de la API (la pantalla pidió algo que no le corresponde, o se rompió);
//   · muestra undefined / NaN / [object Object] / Invalid Date;
//   · es un link del menú que rebota a otro lado;
//   · se sale de la pantalla a lo ancho en el teléfono.
import { test, expect, devices } from '@playwright/test'
import { entrar, sembrar, API } from './helpers.js'

test.beforeAll(() => sembrar('seed', 'autocultivo'))

const ROLES = ['admin', 'cultivador', 'manicura', 'medico', 'dispensador', 'delivery', 'casa']
const ROTO = /\bundefined\b|\bNaN\b|\[object Object\]|Invalid Date/
// Rutas que no son pantallas: salir, descargas, el pasaporte público.
const NO_ES_PANTALLA = /logout|salir|\/login|\/api\/|\/d\/|\.pdf|\.xlsx|^\/?$/

// Los links que el menú de este rol ofrece (sidebar en la compu). Son las pantallas que la persona
// encuentra sin escribir una dirección: si una de esas rompe, la ve.
async function linksDelMenu (page) {
  await page.waitForTimeout(1500)
  const hrefs = await page.$$eval('aside a[href], nav a[href]', as => as.map(a => a.getAttribute('href')))
  return [...new Set(hrefs.filter(h => h && h.startsWith('/') && !h.includes('#')))]
}

// LAS FICHAS, no sólo las listas (21-oct-2026): la ficha del paciente le pedía al dispensador
// notas, indicaciones y documentos (tres 403) y ninguna lista lo mostraba. Las listas abren la
// ficha con un clic en la fila, no con un link, así que los ids salen de la API.
async function fichas (page, rol) {
  const ids = await page.evaluate(async (base) => {
    const get = async (p) => {
      try { const r = await fetch(base + p, { credentials: 'include' }); if (!r.ok) return []; const j = await r.json(); return j.data || j.pacientes || j.dispensaciones || j } catch { return [] }
    }
    const primero = (l) => (Array.isArray(l) && l.length ? l[0].id : null)
    return {
      paciente: primero(await get('/pacientes')), lote: primero(await get('/lotes')),
      sala: primero(await get('/salas')), usuario: primero(await get('/usuarios')),
      stock: primero(await get('/stocks')),
    }
  }, API)
  const por = {
    admin:       [ids.paciente && `/pacientes/${ids.paciente}`, ids.usuario && `/usuarios/${ids.usuario}`,
                  ids.lote && `/lotes/${ids.lote}`, ids.sala && `/salas/${ids.sala}`, ids.stock && `/admin/stock/${ids.stock}`],
    dispensador: [ids.paciente && `/pacientes/${ids.paciente}`],
    medico:      [ids.paciente && `/medico/pacientes/${ids.paciente}`],
    cultivador:  [ids.lote && `/lotes/${ids.lote}`, ids.sala && `/salas/${ids.sala}`],
    casa:        [ids.lote && `/lotes/${ids.lote}`, ids.sala && `/salas/${ids.sala}`],
  }
  return (por[rol] || []).filter(Boolean)
}

function vigilar (page) {
  const fallas = []
  page.on('pageerror', e => fallas.push(`JS: ${e.message}`))
  page.on('response', r => {
    const u = r.url()
    if (!u.includes('/api/') || r.status() < 400) return
    if (r.status() === 401 && u.endsWith('/api/me')) return   // antes de entrar
    fallas.push(`${r.status()} ${r.request().method()} ${u.replace(/^https?:\/\/[^/]+/, '')}`)
  })
  return fallas
}

async function revisar (page, ruta, { telefono }) {
  // Sin `networkidle`: el WebSocket de avisos en vivo nunca deja la red quieta y cada pantalla
  // esperaba 30 s. Carga + un respiro para los pedidos de la pantalla.
  await page.goto(ruta, { waitUntil: 'load' })
  await page.waitForTimeout(1500)
  const problemas = []
  // Rebota si termina FUERA de lo que se pidió (el «No tenés acceso» manda al inicio). Entrar a
  // una subsección es a propósito: /configuracion → /configuracion/club, /mnc → /mnc/pendientes.
  const final = new URL(page.url()).pathname.replace(/\/$/, '')
  const pedida = ruta.split('?')[0].replace(/\/$/, '')
  if (final !== pedida && !(pedida && final.startsWith(pedida + '/'))) problemas.push(`rebota a ${final || '/'}`)
  const { texto, desborde } = await page.evaluate(() => ({
    texto: document.body.innerText,
    desborde: document.documentElement.scrollWidth - window.innerWidth,
  }))
  const roto = texto.split('\n').find(l => ROTO.test(l))
  if (roto) problemas.push(`texto roto: «${roto.trim().slice(0, 80)}»`)
  if (telefono && desborde > 2) problemas.push(`se sale ${desborde}px a lo ancho`)
  return problemas
}

for (const rol of ROLES) {
  test(`${rol}: cada pantalla del menú abre bien, en la compu y en el teléfono`, async ({ browser }) => {
    test.setTimeout(240_000)
    const informe = []

    for (const telefono of [false, true]) {
      const ctx = await browser.newContext(telefono
        ? { ...devices['Pixel 7'], baseURL: test.info().project.use.baseURL, timezoneId: 'America/Argentina/Buenos_Aires', locale: 'es-AR' }
        : { baseURL: test.info().project.use.baseURL, viewport: { width: 1366, height: 820 }, timezoneId: 'America/Argentina/Buenos_Aires', locale: 'es-AR' })
      const page = await ctx.newPage()
      const fallas = vigilar(page)
      await entrar(page, rol)
      const inicio = new URL(page.url()).pathname

      // El menú se lee en la compu (en el teléfono vive en el ☰); en el teléfono se recorren las
      // mismas pantallas.
      const rutas = telefono ? test.info().annotations.find(a => a.type === `rutas-${rol}`)?.description.split(',') ?? []
                             : [inicio, ...(await linksDelMenu(page)).filter(r => !NO_ES_PANTALLA.test(r) && r !== inicio),
                                ...(await fichas(page, rol))]
      if (!telefono) test.info().annotations.push({ type: `rutas-${rol}`, description: rutas.join(',') })

      for (const ruta of rutas) {
        fallas.length = 0
        const problemas = await revisar(page, ruta, { telefono })
        problemas.push(...fallas)
        if (problemas.length) informe.push(`${telefono ? 'teléfono' : 'compu'} ${ruta}: ${problemas.join(' · ')}`)
      }
      expect(rutas.length, `${rol}: el menú no ofreció ninguna pantalla`).toBeGreaterThan(0)
      await ctx.close()
    }

    expect(informe, `${rol}:\n${informe.join('\n')}`).toEqual([])
  })
}
