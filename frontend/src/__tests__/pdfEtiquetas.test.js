import { describe, it, expect, vi } from 'vitest'
import {
  LAYOUT_LOTE, LAYOUT_PLANTA, dibujarEtiquetaLote, dibujarBanderitaPlanta, grillaDe, A4,
} from '../lib/pdfEtiquetas.js'

// Doble de jsPDF: registra qué se dibujó, para poder afirmar geometría y contenido sin generar un
// PDF real (que en jsdom no se puede inspeccionar).
function docFalso() {
  const textos = [], imagenes = [], lineas = [], rects = []
  return {
    textos, imagenes, lineas, rects,
    setDrawColor: vi.fn(), setLineWidth: vi.fn(), setTextColor: vi.fn(),
    setFont: vi.fn(), setFontSize: vi.fn(), setLineDashPattern: vi.fn(),
    roundedRect: (x, y, w, h) => rects.push({ x, y, w, h }),
    addImage: (data, fmt, x, y, w, h) => imagenes.push({ data, fmt, x, y, w, h }),
    text: (t, x, y) => textos.push({ t, x, y }),
    line: (x1, y1, x2, y2) => lineas.push({ x1, y1, x2, y2 }),
    // splitTextToSize real-ish: parte por palabras según un ancho aproximado en mm
    splitTextToSize: (txt, ancho) => {
      const palabras = String(txt).split(' ')
      const porLinea = Math.max(1, Math.floor(ancho / 2.2))
      const out = []
      let actual = ''
      for (const p of palabras) {
        if ((actual + ' ' + p).trim().length > porLinea) { out.push(actual.trim()); actual = p }
        else actual = `${actual} ${p}`
      }
      if (actual.trim()) out.push(actual.trim())
      return out
    },
  }
}

const LOTE = {
  qrDataUrl: 'data:image/png;base64,AAAA',
  codigo: 'L-26-061', genetica: 'ZKKW - Tropicanna', estado: 'Enraizado',
  inicio: '2026-07-22', plantas: 12, clubName: 'Mitocondria_TEST',
}

describe('grilla de la hoja', () => {
  it('el lote entra 3 por fila en A4 apaisada (y 4 no)', () => {
    const g = grillaDe(LAYOUT_LOTE, A4.landscape)
    expect(g.cols).toBe(3)
    expect(3 * LAYOUT_LOTE.ancho + 2 * LAYOUT_LOTE.gap).toBeLessThanOrEqual(A4.landscape.ancho - LAYOUT_LOTE.margen * 2)
    expect(4 * LAYOUT_LOTE.ancho).toBeGreaterThan(A4.landscape.ancho - LAYOUT_LOTE.margen * 2)
  })

  it('en vertical solo entrarían 2: por eso la hoja es apaisada', () => {
    expect(grillaDe(LAYOUT_LOTE, A4.portrait).cols).toBe(2)
  })

  it('la hoja de lotes rinde 9 por página', () => {
    expect(grillaDe(LAYOUT_LOTE, A4.landscape).porPagina).toBe(9)
  })

  it('la banderita de planta va 1 por fila y varias filas', () => {
    const g = grillaDe(LAYOUT_PLANTA, A4.portrait)
    expect(g.cols).toBe(1)
    expect(g.filas).toBeGreaterThanOrEqual(9)
  })
})

describe('dibujarEtiquetaLote', () => {
  it('dibuja el marco, el QR y los textos del lote', () => {
    const doc = docFalso()
    dibujarEtiquetaLote(doc, 0, 0, LOTE)

    expect(doc.rects[0]).toMatchObject({ w: LAYOUT_LOTE.ancho, h: LAYOUT_LOTE.alto })
    expect(doc.imagenes[0]).toMatchObject({ fmt: 'PNG', w: 36, h: 36 })

    const texto = doc.textos.map(t => t.t).join(' | ')
    expect(texto).toContain('L-26-061')
    expect(texto).toContain('Enraizado')
    expect(texto).toContain('inicio 22/07/2026')   // fecha en formato argentino
    expect(texto).toContain('12 plantas')
    expect(texto).toContain('Mitocondria_TEST')
  })

  it('el nombre largo de la genética se reparte en 2 líneas en vez de cortarse', () => {
    const doc = docFalso()
    dibujarEtiquetaLote(doc, 0, 0, { ...LOTE, genetica: 'Lemonesia - Tropicanna Poison' })
    const juntas = doc.textos.map(t => t.t).join(' ')
    expect(juntas).toContain('Lemonesia')
    expect(juntas).toContain('Tropicanna')
    expect(juntas).not.toContain('…')
  })

  // Las fuentes estándar del PDF no traen emoji: si se cuela uno, sale basura impresa.
  it('no mete emoji en el PDF', () => {
    const doc = docFalso()
    dibujarEtiquetaLote(doc, 0, 0, LOTE)
    const juntas = doc.textos.map(t => t.t).join('')
    expect(/\p{Extended_Pictographic}/u.test(juntas)).toBe(false)
  })

  it('respeta el desplazamiento de la celda en la hoja', () => {
    const doc = docFalso()
    dibujarEtiquetaLote(doc, 100, 50, LOTE)
    expect(doc.rects[0]).toMatchObject({ x: 100, y: 50 })
    expect(doc.imagenes[0].x).toBeGreaterThanOrEqual(100)
    expect(doc.textos.every(t => t.x >= 100 && t.y >= 50)).toBe(true)
  })

  it('sin fecha no escribe el texto de inicio', () => {
    const doc = docFalso()
    dibujarEtiquetaLote(doc, 0, 0, { ...LOTE, inicio: null })
    expect(doc.textos.map(t => t.t).join(' ')).not.toContain('inicio')
  })
})

describe('dibujarBanderitaPlanta', () => {
  const PLANTA = {
    qrDataUrl: 'data:image/png;base64,BBBB',
    nombre: 'PL-0012', genetica: 'Blue Sherbet', lote: 'L-26-048',
    inicio: '2026-07-22', clubName: 'Mitocondria_TEST',
  }

  it('duplica el contenido en las dos mitades (se pliega sobre el tronco)', () => {
    const doc = docFalso()
    dibujarBanderitaPlanta(doc, 0, 0, PLANTA)

    expect(doc.imagenes).toHaveLength(2)                       // un QR por cara
    const izq = doc.imagenes[0].x, der = doc.imagenes[1].x
    expect(der - izq).toBeCloseTo(LAYOUT_PLANTA.ancho / 2, 5)

    const cuantas = doc.textos.filter(t => t.t === 'PL-0012').length
    expect(cuantas).toBe(2)
  })

  it('marca la línea de plegado en el medio', () => {
    const doc = docFalso()
    dibujarBanderitaPlanta(doc, 0, 0, PLANTA)
    expect(doc.lineas[0].x1).toBe(LAYOUT_PLANTA.ancho / 2)
    expect(doc.setLineDashPattern).toHaveBeenCalled()
  })
})
