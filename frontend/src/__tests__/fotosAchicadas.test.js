import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { achicarImagen } from '../lib/imagenes.js'

const SRC  = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const leer = (rel) => readFileSync(resolve(SRC, rel), 'utf8')

// Una foto del teléfono pesa 3–6 MB y la galería la muestra de 120 px. Achicarla antes de subir
// es la primera capa del ahorro de bucket (20-sep-2026); el tope del plan es la segunda.
describe('Las fotos se achican antes de subir', () => {
  it('todas las puertas por las que entra una foto pasan por achicarImagen', () => {
    for (const v of ['components/lotes/LoteGaleria.vue',
                     'components/layout/MobileShell.vue',
                     'views/mobile/MSalaMobileDetail.vue',
                     'views/PlantaDetailView.vue']) {
      expect(leer(v), v).toContain('achicarImagen(')
    }
  })

  // Lo que no es imagen, o ya es chico, no se toca: achicar un PNG de 40 KB a JPEG lo empeora.
  it('deja pasar lo que no es imagen o ya es chico', async () => {
    const pdf = new File(['x'], 'a.pdf', { type: 'application/pdf' })
    expect(await achicarImagen(pdf)).toBe(pdf)
    const chica = new File([new Uint8Array(1000)], 'a.png', { type: 'image/png' })
    expect(await achicarImagen(chica)).toBe(chica)
  })

  // Sin canvas (jsdom, un navegador viejo) devuelve el original: subir grande es mejor que no subir.
  it('si el navegador no puede, devuelve el archivo original', async () => {
    const grande = new File([new Uint8Array(2 * 1024 * 1024)], 'a.jpg', { type: 'image/jpeg' })
    expect(await achicarImagen(grande)).toBe(grande)
  })

  // El tope del plan viaja en el 402 con `mensaje`: la pantalla lo muestra tal cual.
  it('el mensaje del tope del plan llega a la persona', () => {
    for (const v of ['components/lotes/LoteGaleria.vue', 'components/layout/MobileShell.vue',
                     'views/mobile/MSalaMobileDetail.vue', 'views/PlantaDetailView.vue']) {
      expect(leer(v), v).toContain('data?.mensaje')
    }
    expect(leer('components/lotes/LoteGaleria.vue')).toContain('cupoLleno')
  })
})
