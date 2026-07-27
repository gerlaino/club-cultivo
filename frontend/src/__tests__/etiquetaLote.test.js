import { describe, it, expect } from 'vitest'
import { etiquetaLoteHTML, hojaTandaCSS, hojaUnaEtiquetaCSS } from '../lib/etiquetaLote.js'

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

  it('la hoja en tanda es A4 y no parte etiquetas entre páginas', () => {
    expect(hojaTandaCSS).toContain('size: A4')
    expect(hojaTandaCSS).toContain('page-break-inside: avoid')
  })

  it('la hoja individual usa el tamaño de la etiqueta', () => {
    expect(hojaUnaEtiquetaCSS).toContain('size: 80mm 50mm')
  })
})
