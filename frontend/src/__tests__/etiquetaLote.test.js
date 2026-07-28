import { describe, it, expect } from 'vitest'
import {
  etiquetaLoteHTML, etiquetaLoteCSS, hojaTandaCSS, hojaUnaEtiquetaCSS, ET_ANCHO_MM, ET_ALTO_MM,
} from '../lib/etiquetaLote.js'

const BASE = {
  qrDataUrl: 'data:image/png;base64,AAAA',
  codigo: 'L-2026-07',
  genetica: 'Northern Lights',
  estado: 'Vegetativo',
  inicio: '2026-07-05',
  plantas: 12,
  clubName: 'Mi Club',
}

describe('etiquetaLoteHTML', () => {
  it('pone el QR, el código, la genética y el conteo de plantas', () => {
    const html = etiquetaLoteHTML(BASE)
    expect(html).toContain('data:image/png;base64,AAAA')
    expect(html).toContain('L-2026-07')
    expect(html).toContain('Northern Lights')
    expect(html).toContain('12 plantas')
    expect(html).toContain('Mi Club')
  })

  it('muestra la fecha en formato argentino', () => {
    expect(etiquetaLoteHTML(BASE)).toContain('inicio 05/07/2026')
  })

  it('sin fecha no inventa el texto de inicio', () => {
    const html = etiquetaLoteHTML({ ...BASE, inicio: null })
    expect(html).not.toContain('inicio')
  })

  it('cae en un guion cuando no hay genética', () => {
    expect(etiquetaLoteHTML({ ...BASE, genetica: null })).toContain('🌿 —')
  })

  // El código y la genética salen de la base y se inyectan como HTML: si no se escapan, un nombre
  // con "<" rompe la hoja de etiquetas.
  it('escapa el HTML de los datos', () => {
    const html = etiquetaLoteHTML({ ...BASE, genetica: '<script>alert(1)</script>' })
    expect(html).not.toContain('<script>')
    expect(html).toContain('&lt;script&gt;')
  })

  it('la hoja en tanda es A4 apaisada y no parte etiquetas entre páginas', () => {
    expect(hojaTandaCSS).toContain('size: A4 landscape')
    expect(hojaTandaCSS).toContain('page-break-inside: avoid')
  })

  // El ancho fijo de la hoja es lo que hace que el HTML descargado se vea igual que impreso: sin
  // eso el flex-wrap usaba el ancho de la ventana y mostraba 6 por fila en vez de 3.
  it('la hoja en tanda fija el ancho de la página para que entren 3 por fila', () => {
    expect(hojaTandaCSS).toContain('width: 287mm')
    expect(3 * ET_ANCHO_MM + 2 * 2).toBeLessThanOrEqual(287)
    expect(4 * ET_ANCHO_MM).toBeGreaterThan(287)   // 4 no entran: son exactamente 3
  })

  it('la hoja individual usa el tamaño de la etiqueta', () => {
    expect(hojaUnaEtiquetaCSS).toContain(`size: ${ET_ANCHO_MM}mm ${ET_ALTO_MM}mm`)
  })

  it('el nombre de la genética envuelve en 2 líneas en vez de cortarse', () => {
    expect(etiquetaLoteCSS).toContain('-webkit-line-clamp: 2')
    expect(etiquetaLoteCSS).not.toContain('white-space: nowrap')
  })
})
