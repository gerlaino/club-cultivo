// EL DESCUENTO DE UNA DISPENSA, como se muestra en las listas: SÓLO el que alguien cargó.
//
// Hasta el 7-oct-2026 la lista deducía uno comparando el precio cobrado con el precio de HOY del
// primer frasco: con dos frascos de Frutal K a $10.500 y $12.000, una dispensa sin descuento salía
// «-13%». El precio de lista cambia y los frascos de una variedad tienen precios distintos: eso no
// es un descuento.
export function descuentoPct (d) {
  const dp = Number(d?.descuento_paciente_pct) || 0
  const dd = Number(d?.descuento_dispensa_pct) || 0
  return dp + dd > 0 ? Math.min(100, Math.round(dp + dd)) : null
}

export const descuentoArs = (d) => Number(d?.descuento_dispensa_ars) || 0
