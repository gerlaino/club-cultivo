// EL STOCK DE FLOR DE UNA SEDE: cuánto hay, si está bajo y cuántos frascos quedan casi vacíos.
//
// «Bajo» es el TOTAL contra el umbral de la organización —la misma regla que el aviso automático
// (`StockBajoJob`)—, no frasco por frasco: contando frascos, una sede con 3.245 g decía «10» en
// rojo porque tenía diez colas de menos de 50 g (7-oct-2026). Los frascos casi vacíos son un dato.
export function resumenStockFlor (stocks, umbral) {
  const flor = (stocks || []).filter(s => s.forma_producto === 'flor_seca')
  const total = flor.reduce((a, s) => a + (Number(s.cantidad) || 0), 0)
  return {
    total,
    bajo: total < umbral,
    casiVacios: flor.filter(s => Number(s.cantidad) > 0 && Number(s.cantidad) < umbral).length,
  }
}
