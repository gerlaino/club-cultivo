import { describe, it, expect } from 'vitest'
import { reprocannCategoria, reprocannBadge, reprocannDias, formatearPlazo } from '../composables/useReprocann.js'

const enDias = (n) => new Date(Date.now() + n * 86400000).toISOString().slice(0, 10)

// AC: el ESTADO manda sobre la fecha. Un trámite pendiente de aprobación todavía no tiene
// certificado —por eso no tiene número ni vencimiento— y se informaba como "Sin REPROCANN",
// que es lo contrario de lo que pasa.
describe('clasificación REPROCANN', () => {
  it('un trámite pendiente SIN número ni fecha no es "sin REPROCANN"', () => {
    const p = { reprocann_estado: 'pendiente', reprocann_numero: null, reprocann_vencimiento: null }

    expect(reprocannCategoria(p)).toBe('pendiente')
    expect(reprocannBadge(p).label).toBe('En trámite')
  })

  it('un pendiente con la fecha ya vencida sigue en trámite, no vencido', () => {
    const p = { reprocann_estado: 'pendiente', reprocann_numero: 'R-1', reprocann_vencimiento: enDias(-10) }

    expect(reprocannCategoria(p)).toBe('pendiente')
  })

  it('sin número y sin trámite sí es "sin REPROCANN"', () => {
    expect(reprocannCategoria({ reprocann_estado: 'sin_registro' })).toBe('sin_reprocann')
  })

  it('el backend puede pisar el estado: activo vencido llega como "vencido"', () => {
    const p = { reprocann_estado: 'activo', reprocann_estado_efectivo: 'vencido',
                reprocann_numero: 'R-2', reprocann_vencimiento: enDias(-1) }

    expect(reprocannCategoria(p)).toBe('vencido')
  })

  it('vence dentro de 30 días → por_vencer; más allá → vigente', () => {
    const numero = { reprocann_estado: 'activo', reprocann_numero: 'R-3' }

    expect(reprocannCategoria({ ...numero, reprocann_vencimiento: enDias(15) })).toBe('por_vencer')
    expect(reprocannCategoria({ ...numero, reprocann_vencimiento: enDias(200) })).toBe('vigente')
  })

  it('un certificado sin fecha cargada existe igual: cuenta como vigente', () => {
    const p = { reprocann_estado: 'activo', reprocann_numero: 'R-4', reprocann_vencimiento: null }

    expect(reprocannCategoria(p)).toBe('vigente')
  })

  // Las categorías son la base de los KPIs de la lista: si no son excluyentes, los
  // contadores no suman el total y el admin ve números que no cierran.
  it('las categorías son mutuamente excluyentes: cada paciente cae en exactamente una', () => {
    const poblacion = [
      { reprocann_estado: 'pendiente' },
      { reprocann_estado: 'sin_registro' },
      { reprocann_estado: 'activo', reprocann_numero: 'a', reprocann_vencimiento: enDias(-5) },
      { reprocann_estado: 'activo', reprocann_numero: 'b', reprocann_vencimiento: enDias(10) },
      { reprocann_estado: 'activo', reprocann_numero: 'c', reprocann_vencimiento: enDias(300) },
      { reprocann_estado: 'activo', reprocann_numero: 'd', reprocann_vencimiento: null },
    ]

    const cats = ['vigente', 'por_vencer', 'vencido', 'pendiente', 'sin_reprocann']
    const suma = cats.reduce(
      (acc, c) => acc + poblacion.filter(p => reprocannCategoria(p) === c).length, 0)

    expect(suma).toBe(poblacion.length)
  })
})

// AC (Germán): "947 días restantes la verdad es feo y muy poco intuitivo de cuánto falta".
// El plazo se dice como lo diría una persona: años y meses, meses y días, o días.
describe('cuánto falta, en castellano', () => {
  const el = (iso) => new Date(iso + 'T00:00:00')

  it('más de un año: años y meses', () => {
    expect(formatearPlazo(el('2026-08-15'), el('2029-03-15'))).toBe('2 años y 7 meses')
  })

  // Con años, los días son ruido: nadie planifica un vencimiento a dos años por el día exacto.
  it('con años no agrega los días', () => {
    expect(formatearPlazo(el('2026-08-15'), el('2029-03-18'))).toBe('2 años y 7 meses')
  })

  it('menos de un año: meses y días', () => {
    expect(formatearPlazo(el('2026-08-15'), el('2026-11-27'))).toBe('3 meses y 12 días')
  })

  it('menos de un mes: sólo días', () => {
    expect(formatearPlazo(el('2026-08-15'), el('2026-08-27'))).toBe('12 días')
  })

  it('el singular no dice "1 años"', () => {
    expect(formatearPlazo(el('2026-08-15'), el('2027-09-16'))).toBe('1 año y 1 mes')
    expect(formatearPlazo(el('2026-08-15'), el('2026-08-16'))).toBe('1 día')
  })

  // Los meses no miden lo mismo: dividir días por 30 daría "3 meses y 2 días" acá.
  it('el mismo día de otro mes son meses justos', () => {
    expect(formatearPlazo(el('2026-08-15'), el('2026-11-15'))).toBe('3 meses')
    expect(formatearPlazo(el('2026-01-31'), el('2026-02-28'))).toBe('28 días')
  })

  it('vence hoy', () => {
    expect(formatearPlazo(el('2026-08-15'), el('2026-08-15'))).toBe('hoy')
  })
})

// AC (Germán, 27-ago): cuatro pacientes cuyo REPROCANN vencía el 28 aparecían en la lista como
// "0d". "0d" se lee como VENCIDO, y no lo estaban: les quedaba un día.
//
// La cuenta va por calendario. La hora del día NO participa: el vencimiento es una fecha sin
// hora, así que restar milisegundos contra `new Date()` perdía siempre un día. El límite que
// importa es el mismo que usa el backend (`vencido if vencimiento < hoy`): el certificado vale
// TODO su último día.
describe('cuántos días faltan — por calendario, no por milisegundos', () => {
  const hoy = new Date(2026, 7, 27, 13, 30) // 27-ago-2026 13:30, con hora del día
  const pac = (vence) => ({ reprocann_estado: 'activo', reprocann_numero: 'R-1', reprocann_vencimiento: vence })

  it('el que vence MAÑANA tiene 1 día, no 0', () => {
    expect(reprocannDias(pac('2026-08-28'), hoy)).toBe(1)
    expect(reprocannBadge(pac('2026-08-28'), hoy).label).toBe('1d')
  })

  it('el que vence HOY todavía no está vencido, y no dice "0d"', () => {
    expect(reprocannDias(pac('2026-08-27'), hoy)).toBe(0)
    expect(reprocannCategoria(pac('2026-08-27'), hoy)).toBe('por_vencer')
    expect(reprocannBadge(pac('2026-08-27'), hoy).label).toBe('Hoy')
  })

  it('el que venció AYER sí está vencido', () => {
    expect(reprocannDias(pac('2026-08-26'), hoy)).toBe(-1)
    expect(reprocannCategoria(pac('2026-08-26'), hoy)).toBe('vencido')
    expect(reprocannBadge(pac('2026-08-26'), hoy).label).toBe('Vencido')
  })

  it('la hora del día no mueve la cuenta: a las 00:01 falta lo mismo que a las 23:59', () => {
    const p = pac('2026-09-10')
    expect(reprocannDias(p, new Date(2026, 7, 27, 0, 1))).toBe(14)
    expect(reprocannDias(p, new Date(2026, 7, 27, 23, 59))).toBe(14)
  })

  it('cruzar el fin de mes no descuenta un día de más', () => {
    expect(reprocannDias(pac('2026-09-01'), new Date(2026, 7, 31, 18, 0))).toBe(1)
  })
})
