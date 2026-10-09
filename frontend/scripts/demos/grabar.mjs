// GRABA «MIRÁ CÓMO SE HACE» (página pública): la app de verdad, con Playwright, sobre el club demo
// `asociacion_ejemplo` (y `autocultivo_ejemplo` para autocultivo). Cada flujo deja un video mudo
// en `public/demos/<id>.mp4` con su portada `.jpg` (ver `comprimir.mjs`) y sus pasos —en qué
// segundo empieza cada uno— en `src/components/public/demos/tiempos.json`, que lee el reproductor.
//
//   npm run demos                      # todos (prepara los datos antes)
//   npm run demos -- genetica-compu    # sólo los que contienen ese texto
//
// Necesita el entorno de docker andando (la app en :5173 y el backend) y un ffmpeg con libx264. Los flujos están en
// `flujos.mjs`. Cada toma crea cosas de verdad: por eso antes se corre `rake demo:preparar_tomas`.
import { chromium } from 'playwright'
import { execSync } from 'node:child_process'
import { readFileSync, writeFileSync, renameSync, mkdirSync, existsSync } from 'node:fs'
import { FLUJOS } from './flujos.mjs'
import { AUTOCULTIVO, armarBaseAutocultivo } from './base-autocultivo.mjs'
import { comprimir, VIDEOS, TIEMPOS } from './comprimir.mjs'

const BASE = process.env.DEMOS_BASE || 'http://localhost:5173'
const CLAVE = process.env.DEMOS_CLAVE || 'DemoVideo2026!'
const RAIZ = new URL('../../', import.meta.url).pathname
const TAMANO = { compu: { width: 1280, height: 800 }, telefono: { width: 390, height: 844 } }

const filtros = process.argv.slice(2)
const elegidos = FLUJOS.filter(f => !filtros.length || filtros.some(x => f.id.includes(x)))
if (!elegidos.length) { console.error('Ningún flujo coincide con', filtros); process.exit(1) }

mkdirSync(VIDEOS, { recursive: true })
mkdirSync(new URL('.', 'file://' + TIEMPOS).pathname, { recursive: true })
const tiempos = existsSync(TIEMPOS) ? JSON.parse(readFileSync(TIEMPOS, 'utf8')) : {}

// Antes de cada grupo (compu, teléfono, autocultivo) se aparta lo de la toma anterior: dentro de un
// grupo los flujos se encadenan (el lote usa la genética recién creada), pero entre grupos se
// repetirían los mismos datos (el mismo DNI, la paciente que ya tiene plata a favor).
const preparar = () => execSync("docker compose exec -T backend sh -lc 'bundle exec rake demo:preparar_tomas'", { cwd: RAIZ + '..', stdio: 'inherit' })
const grupo = (f) => `${f.vista}·${f.usuario}`

const navegador = await chromium.launch()
if (elegidos.some(f => f.usuario === AUTOCULTIVO)) await armarBaseAutocultivo(navegador, { BASE, CLAVE })
let grupoAnterior = null
for (const flujo of elegidos) {
  if (grupo(flujo) !== grupoAnterior) { preparar(); grupoAnterior = grupo(flujo) }
  console.log(`\n▶ ${flujo.id}`)
  tiempos[flujo.id] = await grabar(flujo)
  writeFileSync(TIEMPOS, JSON.stringify(tiempos, null, 2) + '\n')
}
await navegador.close()

async function grabar (flujo) {
  const tel = flujo.vista === 'telefono'
  const vp = TAMANO[flujo.vista]
  const opciones = { viewport: vp, isMobile: tel, hasTouch: tel }

  // La sesión, fuera de cámara.
  const previa = await navegador.newContext(opciones)
  const l = await previa.newPage()
  await l.goto(BASE + '/login'); await l.waitForSelector('input[type="password"]')
  await l.fill('input[type="email"]', flujo.usuario)
  await l.fill('input[type="password"]', CLAVE)
  await l.click('button[type="submit"]'); await l.waitForURL(u => !u.pathname.includes('/login'))
  await l.waitForTimeout(1200)
  const sesion = await previa.storageState()
  await previa.close()

  const ctx = await navegador.newContext({ ...opciones, storageState: sesion, recordVideo: { dir: VIDEOS, size: vp } })
  await ctx.addInitScript(dibujarCursor, tel)
  // Los tiempos se miden desde que arranca el video. La carga de la pantalla de partida queda
  // grabada antes de `inicio`: el reproductor arranca (y vuelve) desde ahí.
  const tVideo = Date.now()
  const p = await ctx.newPage()
  // Un flujo que «termina» sin haber guardado nada es la peor toma: se ve bien y miente.
  const fallas = []
  p.on('response', async r => {
    if (r.url().includes('/api/') && r.status() >= 400 && r.request().method() !== 'GET') {
      fallas.push(`${r.status()} ${r.request().method()} ${r.url()} ${(await r.text().catch(() => '')).slice(0, 200)}`)
    }
  })
  await p.goto(BASE + flujo.ruta); await p.waitForLoadState('networkidle').catch(() => {})
  await p.waitForTimeout(900)
  const inicio = +((Date.now() - tVideo) / 1000).toFixed(2)
  const t0 = tVideo
  const pasos = []
  const h = ayudas(p, tel, (texto) => {
    pasos.push({ t: +((Date.now() - t0) / 1000).toFixed(2), texto })
    console.log('  ', pasos.at(-1).t, texto)
  })
  await flujo.hacer(h)
  await p.waitForTimeout(600)
  if (fallas.length) throw new Error(`${flujo.id}: la app rechazó algo durante la toma\n${fallas.join('\n')}`)
  const duracion = +((Date.now() - t0) / 1000).toFixed(2)
  const video = p.video()
  await ctx.close()
  renameSync(await video.path(), VIDEOS + `${flujo.id}.webm`)
  return { titulo: flujo.titulo, quien: flujo.quien, ...comprimir(flujo.id, inicio), inicio, duracion, pasos }
}

// Acciones con el cursor (o el dedo) a la vista: Playwright no lo dibuja en el video.
function ayudas (p, tel, paso) {
  const pausa = (ms) => p.waitForTimeout(ms)
  async function tocar (loc) {
    await loc.scrollIntoViewIfNeeded()
    const bb = await loc.boundingBox()
    await p.mouse.move(bb.x + bb.width / 2, bb.y + bb.height / 2, { steps: tel ? 1 : 12 })
    await pausa(tel ? 280 : 160)
    await p.mouse.down(); await pausa(80); await p.mouse.up()
  }
  // `deUna`: los montos se ponen de una vez; tipeados número por número la app muestra un
  // momento «Faltan $…» en rojo, que en una vitrina parece un error.
  async function escribir (loc, texto, { deUna = false } = {}) {
    await tocar(loc)
    await loc.fill('')
    if (deUna) { await pausa(250); await loc.fill(texto) } else await loc.pressSequentially(texto, { delay: 70 })
  }
  // La opción por un pedazo de su texto («Gelato 41» elige «Gelato 41 — hibrida»).
  async function elegir (loc, texto) {
    await tocar(loc)
    await pausa(250)
    const valor = await loc.evaluate((sel, t) => [...sel.options].find(o => o.textContent.includes(t))?.value, texto)
    if (valor === undefined) throw new Error(`No hay una opción con «${texto}»`)
    await loc.selectOption(valor)
  }
  return { p, tel, pausa, tocar, escribir, elegir, paso }
}

function dibujarCursor (telefono) {
  addEventListener('DOMContentLoaded', () => {
    const c = document.createElement('div')
    c.style.cssText = telefono
      ? 'position:fixed;z-index:2147483647;width:34px;height:34px;margin:-17px 0 0 -17px;border-radius:50%;background:rgba(46,107,74,.28);border:2px solid rgba(46,107,74,.7);pointer-events:none;opacity:0;transition:opacity .2s,transform .15s;left:-50px;top:-50px'
      : 'position:fixed;z-index:2147483647;width:18px;height:18px;margin:-2px 0 0 -2px;pointer-events:none;left:-50px;top:-50px;transition:transform .12s'
    if (!telefono) c.innerHTML = '<svg width="18" height="18" viewBox="0 0 18 18"><path d="M2 1l13 7.5-6 1.4-2.6 5.6z" fill="#15301F" stroke="#fff" stroke-width="1.4" stroke-linejoin="round"/></svg>'
    document.body.appendChild(c)
    addEventListener('mousemove', e => { c.style.left = e.clientX + 'px'; c.style.top = e.clientY + 'px' }, true)
    addEventListener('mousedown', () => { c.style.transform = 'scale(.8)'; if (telefono) c.style.opacity = '1' }, true)
    addEventListener('mouseup', () => { c.style.transform = ''; if (telefono) setTimeout(() => { c.style.opacity = '0' }, 250) }, true)
  })
}
