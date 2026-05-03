export function formatValor(valor, decimals = 2) {
  if (valor == null) return '—'
  const n = parseFloat(valor)
  if (isNaN(n)) return '—'
  return n.toFixed(decimals)
}
