// Pasa una toma de Playwright (WebM VP8, pesada y sin garantía en el iPhone) a lo que se publica:
// `<id>.mp4` en H.264 —se ve en cualquier navegador y arranca antes de bajarse entero
// (`faststart`)— y `<id>.jpg`, el cuadro donde arrancan los pasos, para que el recuadro no quede
// vacío mientras carga. Un 2,4 MB pasa a ~0,5 MB sin que se note en la pantalla. Borra el WebM.
//
//   node scripts/demos/comprimir.mjs    # comprime los .webm que hayan quedado en public/demos
//
// Necesita un `ffmpeg` con libx264 en el PATH (o en `FFMPEG`): el que trae Playwright sólo sabe VP8.
import { execFileSync } from 'node:child_process'
import { readdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs'

const FFMPEG = process.env.FFMPEG || 'ffmpeg'
const RAIZ = new URL('../../', import.meta.url).pathname
export const VIDEOS = RAIZ + 'public/demos/'
export const TIEMPOS = RAIZ + 'src/components/public/demos/tiempos.json'

const ff = (...args) => execFileSync(FFMPEG, ['-v', 'error', '-y', ...args], { stdio: 'inherit' })

// Devuelve las URLs públicas del video y su portada.
export function comprimir(id, inicio = 0) {
  const webm = VIDEOS + `${id}.webm`
  ff('-i', webm, '-c:v', 'libx264', '-preset', 'slow', '-crf', '30', '-tune', 'animation',
     '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', VIDEOS + `${id}.mp4`)
  ff('-ss', String(inicio), '-i', webm, '-frames:v', '1', '-q:v', '4', VIDEOS + `${id}.jpg`)
  rmSync(webm)
  return { video: `/demos/${id}.mp4`, portada: `/demos/${id}.jpg` }
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
  const tiempos = JSON.parse(readFileSync(TIEMPOS, 'utf8'))
  for (const archivo of readdirSync(VIDEOS).filter(a => a.endsWith('.webm'))) {
    const id = archivo.replace(/\.webm$/, '')
    console.log('comprimiendo', id)
    const urls = comprimir(id, tiempos[id]?.inicio)
    if (tiempos[id]) Object.assign(tiempos[id], urls)
  }
  writeFileSync(TIEMPOS, JSON.stringify(tiempos, null, 2) + '\n')
}
