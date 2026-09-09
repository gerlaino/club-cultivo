import { describe, it, expect } from 'vitest'
import {
  hoyLocal, fmtMiles, parseMonto, FLOWS, FLOWS_ORDEN,
  destinoVacio, destinoEstado, destinoPayload, costoUnitario,
  validarMovimiento, esValido,
  familiaDeDeposito, depositosDeFamilia, depositosDeFamiliaEnSede, sedesConDeposito,
} from '../components/contabilidad/movimientoFlows.js'

describe('hoyLocal', () => {
  it('toma el día LOCAL del Date', () => {
    expect(hoyLocal(new Date(2026, 6, 27, 22, 30))).toBe('2026-07-27')
  })

  it('no se corre de día como toISOString en husos negativos (AR = UTC−3)', () => {
    // Sin depender del huso del runner (corre en UTC): un Date que en AR son las 22:30 del 27 y en
    // UTC ya es el 28. Con toISOString el movimiento nacía con la fecha de mañana.
    const nocheEnAR = {
      getFullYear: () => 2026, getMonth: () => 6, getDate: () => 27,
      toISOString: () => '2026-07-28T01:30:00.000Z',
    }
    expect(hoyLocal(nocheEnAR)).toBe('2026-07-27')
    expect(nocheEnAR.toISOString().slice(0, 10)).toBe('2026-07-28')
  })

  it('padea mes y día', () => {
    expect(hoyLocal(new Date(2026, 0, 5))).toBe('2026-01-05')
  })
})

describe('parseMonto', () => {
  it('formatea miles con punto mientras se tipea', () => {
    expect(parseMonto('80000')).toEqual({ texto: '80.000', monto: 80000 })
    expect(parseMonto('1234567')).toEqual({ texto: '1.234.567', monto: 1234567 })
  })

  it('acepta centavos con coma (monto_ars es decimal(12,2))', () => {
    expect(parseMonto('1234,56')).toEqual({ texto: '1.234,56', monto: 1234.56 })
  })

  it('corta en 2 decimales', () => {
    expect(parseMonto('10,999').monto).toBe(10.99)
  })

  it('tolera que peguen un importe con símbolos', () => {
    expect(parseMonto('$ 1.234,50').monto).toBe(1234.5)
  })

  it('vacío es null, no 0', () => {
    expect(parseMonto('')).toEqual({ texto: '', monto: null })
    expect(parseMonto('abc')).toEqual({ texto: '', monto: null })
  })

  it('la coma sola deja el entero listo para seguir tipeando', () => {
    expect(parseMonto('80,')).toEqual({ texto: '80,', monto: 80 })
  })
})

describe('fmtMiles', () => {
  it('no inventa nada con vacío', () => {
    expect(fmtMiles(null)).toBe('')
    expect(fmtMiles('')).toBe('')
  })
  it('mantiene los decimales con coma', () => {
    expect(fmtMiles(1234.5)).toBe('1.234,5')
  })
})

describe('FLOWS', () => {
  it('cada flujo del orden existe y trae lo que el modal necesita', () => {
    for (const key of FLOWS_ORDEN) {
      const f = FLOWS[key]
      expect(f, key).toBeTruthy()
      expect(f.titulo).toBeTruthy()
      // O es un form (con tipo de asiento y CTA) o es una pantalla propia
      if (f.pantalla) expect(f.pantalla).toBe('fijos')
      else {
        expect(['ingreso', 'egreso']).toContain(f.tipo)
        expect(f.cta).toBeTruthy()
      }
    }
  })

  it('solo el flujo de compra pide destino de stock', () => {
    const conDestino = FLOWS_ORDEN.filter(k => FLOWS[k].pideDestino)
    expect(conDestino).toEqual(['compra'])
  })
})

describe('destino de la mercadería', () => {
  const depCultivo = { id: 7, nombre: 'Cultivo', clave_sistema: 'cultivo', sede_id: 3, activo: true }
  const depSalon   = { id: 9, nombre: 'Salón',   clave_sistema: 'salon',   sede_id: 3, activo: true }

  it('sin depósito elegido no manda destino (la compra es solo gasto)', () => {
    const d = destinoVacio()
    expect(destinoEstado(d, null).iniciado).toBe(false)
    expect(destinoPayload(d, null)).toBeNull()
  })

  it('insumo existente: manda insumo_id y cantidad', () => {
    const d = { ...destinoVacio(), deposito_id: 7, insumo_id: 42, cantidad: 20 }
    expect(destinoPayload(d, depCultivo)).toEqual({
      tipo: 'deposito', deposito_id: 7, cantidad: 20, insumo_id: 42,
    })
  })

  it('insumo nuevo: manda nombre y unidad', () => {
    const d = { ...destinoVacio(), deposito_id: 7, nombre: '  Fertilizante ', unidad_medida: 'litro', cantidad: 5 }
    expect(destinoPayload(d, depCultivo)).toEqual({
      tipo: 'deposito', deposito_id: 7, cantidad: 5, nombre: 'Fertilizante', unidad_medida: 'litro',
    })
  })

  it('el salón manda tipo salon con el bar', () => {
    const d = { ...destinoVacio(), deposito_id: 9, bar_id: 2, bar_producto_id: 5, cantidad: 24 }
    expect(destinoPayload(d, depSalon)).toEqual({
      tipo: 'salon', deposito_id: 9, bar_id: 2, cantidad: 24, bar_producto_id: 5,
    })
  })

  it('a medio llenar no manda nada (no se guarda un asiento que no mueve el stock que prometió)', () => {
    const sinCantidad = { ...destinoVacio(), deposito_id: 7, insumo_id: 42 }
    expect(destinoPayload(sinCantidad, depCultivo)).toBeNull()
    const sinItem = { ...destinoVacio(), deposito_id: 7, cantidad: 10 }
    expect(destinoEstado(sinItem, depCultivo).itemOk).toBe(false)
    expect(destinoPayload(sinItem, depCultivo)).toBeNull()
  })

  it('costoUnitario divide el total por la cantidad', () => {
    expect(costoUnitario(80000, 20)).toBe(4000)
    expect(costoUnitario(80000, 0)).toBeNull()
    expect(costoUnitario(null, 20)).toBeNull()
  })
})

describe('validarMovimiento', () => {
  const valido = {
    categoria_contable_id: 3, descripcion: 'Alquiler julio', monto_ars: 500000, fecha: '2026-07-05',
  }

  it('un movimiento completo no tiene errores', () => {
    expect(esValido(validarMovimiento(valido))).toBe(true)
  })

  it('pide categoría, descripción, monto y fecha', () => {
    const e = validarMovimiento({ descripcion: '   ', monto_ars: 0, fecha: '' })
    expect(Object.keys(e).sort()).toEqual(['categoria', 'descripcion', 'fecha', 'monto_ars'])
  })

  // CAMBIO DE CRITERIO (Germán, ago-2026): LA CATEGORÍA MANDA, así que es obligatoria. De ella
  // salen el sector y si la compra entra a un depósito (y a cuál). Sin categoría el formulario
  // tendría que volver a preguntar las tres cosas, y el gasto terminaría sin sector: invisible
  // en el resultado de cualquier área.
  //
  // Era opcional porque el catálogo arrancaba vacío; ahora la organización nace con una lista
  // sembrada, así que cargar es ELEGIR.
  it('sin categoría no se registra', () => {
    const sinCat = { ...valido, categoria_contable_id: null }
    expect(validarMovimiento(sinCat).categoria).toBeTruthy()
  })

  // La excepción, para no dejar sin salida a lo que no pasa por el formulario (por ejemplo, un
  // alta automática): el contexto puede declarar que la categoría no aplica.
  it('salvo que el contexto diga que no aplica', () => {
    const sinCat = { ...valido, categoria_contable_id: null }
    expect(esValido(validarMovimiento(sinCat, { categoriaOpcional: true }))).toBe(true)
  })

  it('monto 0 o negativo no pasa', () => {
    expect(validarMovimiento({ ...valido, monto_ars: 0 }).monto_ars).toBeTruthy()
    expect(validarMovimiento({ ...valido, monto_ars: -100 }).monto_ars).toBeTruthy()
  })

  it('el paciente es obligatorio solo cuando el contexto lo pide', () => {
    expect(validarMovimiento(valido, { pacienteObligatorio: true }).paciente_id).toBeTruthy()
    expect(validarMovimiento({ ...valido, paciente_id: 8 }, { pacienteObligatorio: true }).paciente_id).toBeFalsy()
    expect(validarMovimiento(valido, { pacienteObligatorio: false }).paciente_id).toBeFalsy()
  })

  it('en cuotas exige al menos 2', () => {
    expect(validarMovimiento({ ...valido, cuotas_total: 1 }, { esCuotas: true }).cuotas_total).toBeTruthy()
    expect(validarMovimiento({ ...valido, cuotas_total: 6 }, { esCuotas: true }).cuotas_total).toBeFalsy()
  })

  it('un destino a medio llenar bloquea el guardado', () => {
    const ctx = { pideDestino: true, destino: { iniciado: true, itemOk: false, cantidad: null } }
    const e = validarMovimiento(valido, ctx)
    expect(e.destino_item).toBeTruthy()
    expect(e.destino_cantidad).toBeTruthy()
  })

  it('un destino sin empezar no molesta (la compra puede ser puro gasto)', () => {
    const ctx = { pideDestino: true, destino: { iniciado: false, itemOk: true, cantidad: null } }
    expect(esValido(validarMovimiento(valido, ctx))).toBe(true)
  })
})

// EL DEPÓSITO NO SE ELIGE: SE DEDUCE — la familia de la categoría POR la sede.
//
// Antes era una grilla con los diez depósitos del club, sin filtrar por la categoría, y el backend
// tampoco validaba: las bolsas del dispensario entraban al depósito de Cultivo de otra sede sin
// una queja. Germán, cargando una compra: «es como que estoy ingresando por duplicado».
describe('De dónde sale el depósito', () => {
  const DEPS = [
    { id: 1, nombre: 'General',      clave_sistema: 'general',      familia: 'insumo_general', sede_id: 10, activo: true },
    { id: 2, nombre: 'General',      clave_sistema: 'general',      familia: 'insumo_general', sede_id: 20, activo: true },
    { id: 3, nombre: 'Cultivo',      clave_sistema: 'cultivo',      familia: 'insumo',         sede_id: 20, activo: true },
    { id: 4, nombre: 'Salón',        clave_sistema: 'salon',        familia: 'mercaderia',     sede_id: 10, activo: true },
    { id: 5, nombre: 'Dispensación', clave_sistema: 'dispensacion', familia: 'mercaderia',     sede_id: 10, activo: true },
    { id: 6, nombre: 'Viejo',        clave_sistema: 'cultivo',      familia: 'insumo',         sede_id: 10, activo: false },
    { id: 7, nombre: 'Taller',       clave_sistema: null,           familia: 'general',        sede_id: 10, activo: true },
  ]

  // Los propios del club llegan con familia 'general', que no existe en ningún otro lado: sin
  // normalizar quedaban inalcanzables apenas el destino empezó a derivarse de la categoría.
  it('un depósito propio del club se comporta como insumos generales', () => {
    expect(familiaDeDeposito({ familia: 'general' })).toBe('insumo_general')
    expect(familiaDeDeposito({ familia: 'insumo' })).toBe('insumo')
    expect(familiaDeDeposito(null)).toBe(null)
  })

  it('sin familia no hay depósito posible: es sólo un gasto', () => {
    expect(depositosDeFamilia(DEPS, null)).toEqual([])
    expect(sedesConDeposito(DEPS, null)).toEqual([])
  })

  it('sólo los de la familia, y sólo los activos', () => {
    expect(depositosDeFamilia(DEPS, 'insumo').map(d => d.id)).toEqual([3])
  })

  // Comparte familia con el Salón, pero ahí no entran compras: lo llena la cosecha.
  it('Dispensación queda afuera aunque sea mercadería', () => {
    expect(depositosDeFamilia(DEPS, 'mercaderia').map(d => d.id)).toEqual([4])
  })

  it('el propio del club aparece junto al General de su sede', () => {
    expect(depositosDeFamiliaEnSede(DEPS, 'insumo_general', 10).map(d => d.id)).toEqual([1, 7])
  })

  it('el de la sede, que es el que se deduce', () => {
    expect(depositosDeFamiliaEnSede(DEPS, 'insumo', 20).map(d => d.id)).toEqual([3])
    expect(depositosDeFamiliaEnSede(DEPS, 'insumo', 10)).toEqual([])   // Cultivo de esa sede está inactivo
    expect(depositosDeFamiliaEnSede(DEPS, 'insumo', null)).toEqual([])
  })

  it('y las sedes donde esta compra puede entrar, sin repetir', () => {
    expect(sedesConDeposito(DEPS, 'insumo_general')).toEqual([10, 20])
    expect(sedesConDeposito(DEPS, 'mercaderia')).toEqual([10])
  })
})
