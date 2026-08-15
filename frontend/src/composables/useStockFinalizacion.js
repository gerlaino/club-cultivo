// Cómo se cierra un stock que no se va a dispensar. Espeja `Stock::MOTIVOS_FINALIZACION` del
// backend, que es quien decide qué movimiento deja cada uno.
//
// La distinción que importa: SÓLO "destruido" es una pérdida. El resto son salidas — el producto
// existe, está en otro lado. Anotar una entrega como merma declara destruido algo intacto, lo
// cuenta el informe de Pérdidas y deja la trazabilidad con gramos que desaparecieron sin
// explicación, que para un auditor es peor que una pérdida declarada.
export const MOTIVOS_FINALIZACION = [
  { value: 'entregado',   label: 'Entregado a otra organización', ayuda: 'Salió entero: lo tiene otro club o dispensario.' },
  { value: 'vendido',     label: 'Vendido',                       ayuda: 'Salida por venta a un tercero.' },
  { value: 'regalado',    label: 'Regalado',                      ayuda: 'Salió sin cobrar y sin paciente identificado.' },
  { value: 'uso_interno', label: 'Uso interno',                   ayuda: 'Consumido por la organización (muestras, pruebas).' },
  { value: 'destruido',   label: 'Destruido / descartado',        ayuda: 'Se perdió: vencido, contaminado, roto. Cuenta como pérdida.' },
]

export const ES_PERDIDA = ['destruido']

export function ayudaDe(motivo) {
  return MOTIVOS_FINALIZACION.find(m => m.value === motivo)?.ayuda || ''
}
