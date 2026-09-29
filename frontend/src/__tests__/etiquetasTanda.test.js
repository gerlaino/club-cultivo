import { describe, it, expect, vi, beforeEach } from 'vitest'

// Que el PDF salga con MENOS etiquetas de las pedidas es el miedo más caro de esta feature: te
// enterás recién con la plancha impresa y las plantas sin etiquetar. Este test recorre el bucle
// real de `useEtiquetasQR` con un doble de jsPDF y cuenta qué salió, para que un ítem perdido en
// el paginado falle acá y no en el invernadero.

const paginas  = { n: 1 }
const imagenes = []
const guardados = []
const orientaciones = []   // la de cada hoja, en orden

vi.mock('jspdf', () => ({
  jsPDF: class {
    constructor(opts) { paginas.n = 1; orientaciones.length = 0; orientaciones.push(opts?.orientation) }
    addPage(_formato, orientacion) { paginas.n++; orientaciones.push(orientacion ?? orientaciones.at(-1)) }
    addImage(data, fmt, x, y) { imagenes.push({ data, x, y, pagina: paginas.n }) }
    text() {}
    setFont() {}; setFontSize() {}; setTextColor() {}; setDrawColor() {}
    setLineWidth() {}; setLineDashPattern() {}; roundedRect() {}; line() {}
    splitTextToSize(t) { return [String(t)] }
    autoPrint() {}
    save(nombre) { guardados.push(nombre) }
    output() { return new Blob() }
  },
}))

vi.mock('../composables/useQRCode.js', () => ({
  useQRCode: () => ({ generatePNG: async (url) => `data:image/png;base64,${url}` }),
}))

const { useEtiquetasQR } = await import('../composables/useEtiquetasQR.js')
const { LAYOUT_PLANTA, LAYOUT_LOTE, dibujarBanderitaPlanta, dibujarEtiquetaLote } =
  await import('../lib/pdfEtiquetas.js')

function plantas(n, lote = 'L-26-048') {
  return Array.from({ length: n }, (_, i) => ({
    id: i + 1,
    nombre: `${lote}-P${String(i + 1).padStart(3, '0')}`,
    codigo_qr: `qr-${i + 1}`,
  }))
}

function configPlantas(items) {
  return () => ({
    items,
    urlDe:   (p) => `https://x/p/${p.codigo_qr}`,
    layout:  LAYOUT_PLANTA,
    dibujar: dibujarBanderitaPlanta,
    datosDe: (p, qr) => ({ qrDataUrl: qr, nombre: p.nombre, genetica: 'G', lote: 'L-26-048' }),
    archivo: 'etiquetas-L-26-048',
  })
}

describe('la tanda no pierde etiquetas', () => {
  beforeEach(() => { imagenes.length = 0; guardados.length = 0; paginas.n = 1 })

  it('12 plantas → 12 etiquetas, repartidas 10 + 2', async () => {
    const et = useEtiquetasQR()
    const r  = await et.descargar(configPlantas(plantas(12)))

    expect(r.ok).toBe(true)
    // Cada banderita dibuja DOS QR (doble faz) → 24 imágenes para 12 plantas.
    expect(imagenes).toHaveLength(24)
    expect(et.hechas.value).toBe(12)
    expect(et.total.value).toBe(12)
    expect(paginas.n).toBe(2)
    const porPagina = [1, 2].map(p => imagenes.filter(i => i.pagina === p).length / 2)
    expect(porPagina).toEqual([10, 2])
    expect(guardados).toEqual(['etiquetas-L-26-048.pdf'])
  })

  it('los 12 QR distintos llegan al PDF (ninguno se saltea ni se repite)', async () => {
    const et = useEtiquetasQR()
    await et.descargar(configPlantas(plantas(12)))

    const unicos = new Set(imagenes.map(i => i.data))
    expect(unicos.size).toBe(12)
    for (let i = 1; i <= 12; i++) {
      expect([...unicos].some(d => d.endsWith(`/p/qr-${i}`))).toBe(true)
    }
  })

  // El borde del paginado: con exactamente una página llena no debe abrirse una segunda vacía.
  it('10 plantas entran en una sola página', async () => {
    const et = useEtiquetasQR()
    await et.descargar(configPlantas(plantas(10)))
    expect(paginas.n).toBe(1)
    expect(imagenes).toHaveLength(20)
  })

  it('la tanda de lotes rinde 9 por página (A4 apaisada)', async () => {
    const lotes = Array.from({ length: 11 }, (_, i) => ({ id: i + 1, codigo: `L-26-0${i}`, codigo_qr: `q${i}` }))
    const et = useEtiquetasQR()
    await et.descargar(() => ({
      items: lotes,
      urlDe:   (l) => `https://x/l/${l.codigo_qr}`,
      layout:  LAYOUT_LOTE,
      dibujar: dibujarEtiquetaLote,
      datosDe: (l, qr) => ({ qrDataUrl: qr, codigo: l.codigo, genetica: 'G', estado: 'Enraizado', plantas: 1 }),
    }))
    expect(imagenes).toHaveLength(11)           // la etiqueta de lote lleva UN QR
    expect(paginas.n).toBe(2)
    expect(imagenes.filter(i => i.pagina === 1)).toHaveLength(9)
  })

  // Lotes + sus plantas en un solo PDF: cada pieza arranca en hoja nueva y con SU orientación, y
  // ninguna etiqueta se pierde al pasar de una tanda a la otra.
  it('dos tandas: los lotes en apaisada, después las plantas en vertical, en hojas aparte', async () => {
    const lotes = Array.from({ length: 2 }, (_, i) => ({ codigo: `L-${i}`, codigo_qr: `l${i}` }))
    const et = useEtiquetasQR()
    await et.descargar(() => ({
      tandas: [
        { items: lotes, urlDe: (l) => `https://x/l/${l.codigo_qr}`, layout: LAYOUT_LOTE, dibujar: dibujarEtiquetaLote,
          datosDe: (l, qr) => ({ qrDataUrl: qr, codigo: l.codigo, genetica: 'G', estado: 'E', plantas: 1 }) },
        { items: plantas(12), urlDe: (p) => `https://x/p/${p.codigo_qr}`, layout: LAYOUT_PLANTA, dibujar: dibujarBanderitaPlanta,
          datosDe: (p, qr) => ({ qrDataUrl: qr, nombre: p.nombre }) },
      ],
      archivo: 'mixto',
    }))

    expect(et.total.value).toBe(14)
    expect(et.hechas.value).toBe(14)
    // Hoja 1: los 2 lotes. Hojas 2 y 3: 10 + 2 banderitas (dos QR cada una).
    expect(orientaciones).toEqual(['landscape', 'portrait', 'portrait'])
    expect(imagenes.filter(i => i.pagina === 1).map(i => i.data)).toEqual(['data:image/png;base64,https://x/l/l0', 'data:image/png;base64,https://x/l/l1'])
    expect(imagenes.filter(i => i.pagina === 2)).toHaveLength(20)
    expect(imagenes.filter(i => i.pagina === 3)).toHaveLength(4)
    expect(guardados).toEqual(['mixto.pdf'])
  })

  it('una tanda vacía no abre una hoja en blanco', async () => {
    const et = useEtiquetasQR()
    await et.descargar(() => ({
      tandas: [
        { items: [], layout: LAYOUT_LOTE },
        { items: plantas(3), urlDe: (p) => `https://x/p/${p.codigo_qr}`, layout: LAYOUT_PLANTA, dibujar: dibujarBanderitaPlanta,
          datosDe: (p, qr) => ({ qrDataUrl: qr, nombre: p.nombre }) },
      ],
    }))
    expect(orientaciones).toEqual(['portrait'])
  })

  it('si no hay ítems no genera nada', async () => {
    const et = useEtiquetasQR()
    const r  = await et.descargar(() => ({ secuencia: [] }))
    expect(r).toMatchObject({ ok: false, vacio: true })
  })

  it('si no hay ítems (una sola pieza) no genera nada', async () => {
    const et = useEtiquetasQR()
    const r  = await et.descargar(configPlantas([]))
    expect(r).toMatchObject({ ok: false, vacio: true })
    expect(guardados).toHaveLength(0)
  })
})

// El orden de la plancha se etiqueta recorriendo el lote, no la línea de tiempo del alta. La tabla
// de /plantas ordena por fecha de creación: un lote ampliado días después llega acá partido en dos
// bloques lejanos, con plantas de otros lotes en el medio.
describe('la plancha sale ordenada por lote y número', () => {
  beforeEach(() => { imagenes.length = 0; guardados.length = 0; paginas.n = 1 })

  // Devuelve los nombres en el orden en que se dibujaron (la banderita repite el QR en las dos
  // mitades, así que cada etiqueta aparece dos veces seguidas).
  function nombresDibujados() {
    return imagenes.map(i => i.data.split('/p/')[1]).filter((n, idx, arr) => n !== arr[idx - 1])
  }

  async function generar(items) {
    const et = useEtiquetasQR()
    await et.descargar(() => ({
      items,
      urlDe:    (p) => `https://x/p/${p.nombre}`,
      layout:   LAYOUT_PLANTA,
      dibujar:  dibujarBanderitaPlanta,
      datosDe:  (p, qr) => ({ qrDataUrl: qr, nombre: p.nombre }),
      ordenPor: (p) => [p.lote?.codigo ?? '', p.nombre ?? ''],
    }))
    return nombresDibujados()
  }

  it('agrupa por lote: uno entero y después el siguiente', async () => {
    // Llegan mezcladas, como las entrega la tabla ordenada por fecha de creación.
    const items = [
      { nombre: 'L-26-061-P002', lote: { codigo: 'L-26-061' } },
      { nombre: 'L-26-048-P002', lote: { codigo: 'L-26-048' } },
      { nombre: 'L-26-061-P001', lote: { codigo: 'L-26-061' } },
      { nombre: 'L-26-048-P001', lote: { codigo: 'L-26-048' } },
    ]
    expect(await generar(items)).toEqual([
      'L-26-048-P001', 'L-26-048-P002', 'L-26-061-P001', 'L-26-061-P002',
    ])
  })

  // El caso real: el lote 48 se creó con 3 plantas y ~20 minutos después se le sumaron 9. Por fecha
  // de creación las P001-P003 quedaban decenas de etiquetas más abajo, entre plantas de otro lote.
  it('reúne un lote cargado en dos tandas separadas en el tiempo', async () => {
    const viejas  = [1, 2, 3].map(n => ({ nombre: `L-26-048-P00${n}`, lote: { codigo: 'L-26-048' } }))
    const nuevas  = [4, 5, 6].map(n => ({ nombre: `L-26-048-P00${n}`, lote: { codigo: 'L-26-048' } }))
    const intrusa = { nombre: 'L-26-061-P012', lote: { codigo: 'L-26-061' } }
    // Orden de llegada: primero las nuevas, después la de otro lote, y al final las viejas.
    const salida = await generar([...nuevas, intrusa, ...viejas])

    expect(salida).toEqual([
      'L-26-048-P001', 'L-26-048-P002', 'L-26-048-P003',
      'L-26-048-P004', 'L-26-048-P005', 'L-26-048-P006',
      'L-26-061-P012',
    ])
  })

  it('P002 va antes que P010 (orden numérico, no alfabético)', async () => {
    const items = ['P010', 'P002', 'P1', 'P20'].map(s => ({ nombre: s, lote: { codigo: 'L' } }))
    expect(await generar(items)).toEqual(['P1', 'P002', 'P010', 'P20'])
  })

  it('sin ordenPor respeta el orden de llegada', async () => {
    const et = useEtiquetasQR()
    await et.descargar(() => ({
      items:   ['b', 'a', 'c'].map(n => ({ nombre: n })),
      urlDe:   (p) => `https://x/p/${p.nombre}`,
      layout:  LAYOUT_PLANTA,
      dibujar: dibujarBanderitaPlanta,
      datosDe: (p, qr) => ({ qrDataUrl: qr, nombre: p.nombre }),
    }))
    expect(nombresDibujados()).toEqual(['b', 'a', 'c'])
  })

  it('no muta el array que le pasa la vista (es la selección viva)', async () => {
    const items = [
      { nombre: 'L-26-061-P001', lote: { codigo: 'L-26-061' } },
      { nombre: 'L-26-048-P001', lote: { codigo: 'L-26-048' } },
    ]
    const copia = [...items]
    await generar(items)
    expect(items).toEqual(copia)
  })

  it('la tanda de lotes sale por código', async () => {
    const et = useEtiquetasQR()
    await et.descargar(() => ({
      items:    ['L-26-061', 'L-26-048', 'L-26-100', 'L-26-009'].map(c => ({ codigo: c })),
      urlDe:    (l) => `https://x/l/${l.codigo}`,
      layout:   LAYOUT_LOTE,
      dibujar:  dibujarEtiquetaLote,
      datosDe:  (l, qr) => ({ qrDataUrl: qr, codigo: l.codigo, genetica: 'G', estado: 'E', plantas: 1 }),
      ordenPor: (l) => [l.codigo ?? ''],
    }))
    expect(imagenes.map(i => i.data.split('/l/')[1]))
      .toEqual(['L-26-009', 'L-26-048', 'L-26-061', 'L-26-100'])
  })
})

// Lote, sus plantas, el lote siguiente — de corrido en A4 vertical (AC de Germán, 29-sep). Lo que
// no puede pasar: una etiqueta partida entre dos hojas, o la del lote sola al pie de una hoja y
// sus plantas en la siguiente.
describe('de corrido: lote, sus plantas, el lote siguiente', () => {
  beforeEach(() => { imagenes.length = 0; guardados.length = 0; paginas.n = 1 })

  // Piezas con el alto real de cada layout, que anotan dónde se dibujaron.
  const dibujadas = []
  const pieza = (layout, tipo) => ({
    layout, urlDe: (x) => `https://x/${x.id}`, datosDe: (x) => x,
    dibujar: (_doc, x, y, d) => dibujadas.push({ id: d.id, tipo, y, alto: layout.alto, pagina: paginas.n }),
  })
  const LOTE   = pieza(LAYOUT_LOTE, 'lote')
  const PLANTA = pieza(LAYOUT_PLANTA, 'planta')
  const lote   = (id, conPlantas = true) => ({ item: { id }, pieza: LOTE, pegadoAlSiguiente: conPlantas })
  const planta = (id) => ({ item: { id }, pieza: PLANTA })

  async function generar(secuencia) {
    dibujadas.length = 0
    const et = useEtiquetasQR()
    const r = await et.descargar(() => ({ secuencia, archivo: 'corrido' }))
    return { r, et }
  }

  it('respeta el orden dado y todo va en A4 vertical', async () => {
    const { r, et } = await generar([lote('A'), planta('A1'), planta('A2'), lote('B'), planta('B1')])
    expect(r.ok).toBe(true)
    expect(dibujadas.map(d => d.id)).toEqual(['A', 'A1', 'A2', 'B', 'B1'])
    expect(et.total.value).toBe(5)
    expect(orientaciones.every(o => o === 'portrait')).toBe(true)
  })

  it('ninguna etiqueta queda partida entre dos hojas', async () => {
    const seq = []
    for (const l of ['A', 'B', 'C', 'D']) {
      seq.push(lote(l))
      for (let i = 1; i <= 6; i++) seq.push(planta(`${l}${i}`))
    }
    await generar(seq)

    expect(dibujadas).toHaveLength(28)
    expect(paginas.n).toBeGreaterThan(1)
    // A4 = 297mm de alto, 8mm de margen.
    for (const d of dibujadas) expect(d.y + d.alto).toBeLessThanOrEqual(297 - 8)
  })

  it('la etiqueta del lote no queda sola al pie: pasa a la hoja siguiente con su primera planta', async () => {
    // 7 banderitas dejan lugar para la etiqueta del lote (60mm) pero no para ella + una banderita.
    const sueltas = Array.from({ length: 7 }, (_, i) => planta(`X${i}`))
    await generar([...sueltas, lote('B'), planta('B1')])

    const b  = dibujadas.find(d => d.id === 'B')
    const b1 = dibujadas.find(d => d.id === 'B1')
    expect(b.pagina).toBe(2)
    expect(b1.pagina).toBe(2)
  })

  it('un lote sin plantas sí puede ir al pie de la hoja', async () => {
    const sueltas = Array.from({ length: 7 }, (_, i) => planta(`X${i}`))
    await generar([...sueltas, lote('B', false)])
    expect(dibujadas.find(d => d.id === 'B').pagina).toBe(1)
  })
})
