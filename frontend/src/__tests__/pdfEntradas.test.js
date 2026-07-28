import { describe, it, expect, vi } from 'vitest'
import { LAYOUT_ENTRADA, LAYOUT_LOTE, LAYOUT_PLANTA, dibujarEntrada, grillaDe, A4 } from '../lib/pdfEtiquetas.js'

// Doble de jsPDF: registra qué se dibujó, para afirmar geometría y contenido sin generar un PDF
// real (que en jsdom no se puede inspeccionar).
function docFalso() {
  const textos = [], imagenes = [], lineas = [], rects = [], circulos = []
  return {
    textos, imagenes, lineas, rects, circulos,
    setDrawColor: vi.fn(), setLineWidth: vi.fn(), setTextColor: vi.fn(), setFillColor: vi.fn(),
    setFont: vi.fn(), setFontSize: vi.fn(), setLineDashPattern: vi.fn(),
    getTextWidth: (t) => String(t).length * 1.8,
    roundedRect: (x, y, w, h) => rects.push({ x, y, w, h }),
    rect: (x, y, w, h) => rects.push({ x, y, w, h, plano: true }),
    circle: (x, y, r) => circulos.push({ x, y, r }),
    addImage: (data, fmt, x, y, w, h) => imagenes.push({ data, fmt, x, y, w, h }),
    text: (t, x, y, opts) => textos.push({ t, x, y, align: opts?.align }),
    line: (x1, y1, x2, y2) => lineas.push({ x1, y1, x2, y2 }),
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

const ENTRADA = {
  qrDataUrl: 'data:image/png;base64,AAAA',
  clubName: 'Mitocondria_TEST', evento: 'Cata Varela',
  fecha: '2026-09-20', horario: '16 a 22',
  tipo: 'General', precio: 12000, comprador: 'Juan Pérez', codigo: 'a1b2c3d4',
}

const junta = (doc) => doc.textos.map(t => t.t).join(' | ')

describe('hoja de entradas', () => {
  it('entran 3 por página A4 vertical', () => {
    const g = grillaDe(LAYOUT_ENTRADA, A4.portrait)
    expect(g.cols).toBe(1)
    expect(g.porPagina).toBe(3)
  })

  it('la entrada entra a lo ancho de la hoja con sus márgenes', () => {
    expect(LAYOUT_ENTRADA.margen * 2 + LAYOUT_ENTRADA.ancho).toBeLessThanOrEqual(A4.portrait.ancho)
  })
})

describe('dibujarEntrada', () => {
  it('imprime el evento, el club, cuándo, a nombre de quién y el código', () => {
    const doc = docFalso()
    dibujarEntrada(doc, 0, 0, ENTRADA)
    const t = junta(doc)

    expect(t).toContain('Cata Varela')
    expect(t).toContain('Mitocondria_TEST')
    expect(t).toContain('20 de septiembre de 2026')
    expect(t).toContain('16 a 22')
    expect(t).toContain('A nombre de Juan Pérez')
    expect(t).toContain('A1B2C3D4')           // el código, en mayúsculas para leerlo en la puerta
    expect(t).toContain('ACCESO')
  })

  // Es una invitación, no un ticket comercial: el bloque de fecha es lo primero que se lee.
  it('el día y el mes van en un bloque destacado, arriba a la izquierda', () => {
    const doc = docFalso()
    dibujarEntrada(doc, 0, 0, ENTRADA)
    const dia = doc.textos.find(t => t.t === '20')
    const mes = doc.textos.find(t => t.t === 'SEP')
    expect(dia).toBeTruthy()
    expect(mes).toBeTruthy()
    // A la izquierda del nombre del evento, y arriba de todo.
    const evento = doc.textos.find(t => t.t.includes('Cata'))
    expect(dia.x).toBeLessThan(evento.x)
    expect(mes.y).toBeGreaterThan(dia.y)
  })

  it('el precio va chico y al pie, no como protagonista', () => {
    const doc = docFalso()
    dibujarEntrada(doc, 0, 0, ENTRADA)
    const precio = doc.textos.find(t => t.t.includes('$12.000'))
    const evento = doc.textos.find(t => t.t.includes('Cata'))
    expect(precio).toBeTruthy()
    expect(precio.y).toBeGreaterThan(evento.y)      // más abajo que el evento
    expect(precio.align).toBe('right')              // alineado al pie derecho, no en el medio
  })

  it('el QR va en el talón, a la derecha del troquel', () => {
    const doc = docFalso()
    dibujarEntrada(doc, 0, 0, ENTRADA)
    const corte = LAYOUT_ENTRADA.ancho - 54
    expect(doc.imagenes).toHaveLength(1)
    expect(doc.imagenes[0].x).toBeGreaterThan(corte)
    expect(doc.imagenes[0].w).toBe(doc.imagenes[0].h)   // cuadrado
  })

  // El troquel es lo que hace que se lea como un ticket: línea punteada + muescas en los cantos.
  it('marca el troquel con línea punteada y muescas arriba y abajo', () => {
    const doc = docFalso()
    dibujarEntrada(doc, 0, 0, ENTRADA)
    const corte = LAYOUT_ENTRADA.ancho - 54

    expect(doc.setLineDashPattern).toHaveBeenCalled()
    expect(doc.lineas[0].x1).toBe(corte)
    expect(doc.lineas[0].x1).toBe(doc.lineas[0].x2)     // vertical
    expect(doc.circulos.map(c => c.y)).toEqual([0, LAYOUT_ENTRADA.alto])
    expect(doc.circulos.every(c => c.x === corte)).toBe(true)
  })

  // Una cata gratis para socios es el caso normal del club: no tiene por qué hablar de plata.
  it('una entrada sin cargo no menciona plata en ningún lado', () => {
    const doc = docFalso()
    dibujarEntrada(doc, 0, 0, { ...ENTRADA, precio: 0 })
    const t = junta(doc)
    expect(t).not.toContain('$')
    expect(t).not.toContain('Sin cargo')     // tampoco hace falta aclararlo
    expect(t).toContain('General')           // el tipo sí se sigue viendo
    expect(t).toContain('Cata Varela')
  })

  it('sin fecha no inventa una', () => {
    const doc = docFalso()
    dibujarEntrada(doc, 0, 0, { ...ENTRADA, fecha: null, horario: null })
    expect(junta(doc)).toContain('Fecha y horario a confirmar')
    expect(junta(doc)).toContain('CONFIRMAR')   // el bloque de fecha tampoco queda vacío
  })

  it('sin comprador no deja un hueco raro', () => {
    const doc = docFalso()
    dibujarEntrada(doc, 0, 0, { ...ENTRADA, comprador: null })
    expect(junta(doc)).toContain('Cata Varela')
    expect(junta(doc)).not.toContain('A nombre de')
  })

  it('un nombre de evento larguísimo se reparte en 2 líneas y no desborda', () => {
    const doc = docFalso()
    dibujarEntrada(doc, 0, 0, { ...ENTRADA, evento: 'Encuentro de cultivadores del sur y degustación abierta a la comunidad' })
    const corte = LAYOUT_ENTRADA.ancho - 54
    // Nada del cuerpo se mete en el talón.
    const cuerpo = doc.textos.filter(t => t.align !== 'center')
    expect(cuerpo.every(t => t.x < corte)).toBe(true)
  })

  it('respeta el desplazamiento de la celda en la hoja', () => {
    const doc = docFalso()
    dibujarEntrada(doc, 15, 40, ENTRADA)
    expect(doc.rects[0]).toMatchObject({ x: 15, y: 40, w: LAYOUT_ENTRADA.ancho, h: LAYOUT_ENTRADA.alto })
    expect(doc.textos.every(t => t.x >= 15 && t.y >= 40)).toBe(true)
    expect(doc.imagenes[0].y).toBeGreaterThanOrEqual(40)
  })

  // Las fuentes estándar del PDF no traen emoji: si se cuela uno, sale basura impresa.
  it('no mete emoji en el PDF', () => {
    const doc = docFalso()
    dibujarEntrada(doc, 0, 0, ENTRADA)
    expect(/\p{Extended_Pictographic}/u.test(doc.textos.map(t => t.t).join(''))).toBe(false)
  })
})

// Estas etiquetas viven en un cuarto de cultivo: se humedecen, se manchan y se pliegan. La
// tolerancia al daño es una decisión de diseño, no un default de librería — si alguien la baja sin
// querer, los QR arruinados dejan de leerse y te enterás recién con la plancha en la mano.
describe('tolerancia al maltrato del QR', () => {
  it('todas las piezas piden corrección de error ALTA y zona muda generosa', () => {
    for (const layout of [LAYOUT_LOTE, LAYOUT_PLANTA, LAYOUT_ENTRADA]) {
      expect(layout.qr.errorCorrectionLevel).toBe('H')   // tolera 30% dañado (el default M, 15%)
      expect(layout.qr.margin).toBeGreaterThanOrEqual(2)
      expect(layout.qr.width).toBeGreaterThanOrEqual(220)
    }
  })

  // La banderita es la que se moja: negro puro, que es el que más contraste da sobre material
  // húmedo o tóner rayado. Las otras viven protegidas y ahí gana la marca.
  it('la banderita de planta va en negro; lote y entrada, en verde', () => {
    expect(LAYOUT_PLANTA.qr.color.dark).toBe('#000000')
    expect(LAYOUT_LOTE.qr.color.dark).toBe('#1b5e20')
    expect(LAYOUT_ENTRADA.qr.color.dark).toBe('#1b5e20')
  })
})
