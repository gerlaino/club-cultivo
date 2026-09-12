// EL TEXTO DEL GUARD al dar vuelta una sala con lotes adentro. Es uno solo para las dos puertas
// (editar la sala y el botón «Cambiar fase») y sale de lo que manda el backend
// (`Salas::CambiarFase`): lote por lote, los días que lleva y qué se cancela.
//
// IDA Y VUELTA NO SON SIMÉTRICAS (sep-2026, decisión de Germán). Volver a vegetativo con lotes
// adentro es DESHACER el paso a floración —nadie revegeta a propósito una planta que ya recibió
// 12/12—, así que se dice exactamente qué se borra (el paso, sus días, las tareas pendientes) y
// qué queda (fotos, notas, riegos): «toda la información se perderá» asusta y no informa.
export function textoCambioDeFase (data) {
  const lotes = data.lotes_afectados || []
  const deshace = !!data.deshace
  const n = lotes.length
  const plural = n !== 1
  const dias = (d) => (d == null ? '' : `${d} día${d === 1 ? '' : 's'} en ${deshace ? 'floración' : 'vegetativo'}`)

  const lineas = lotes.map(l => {
    const partes = [dias(l.dias_en_fase), `${l.plantas} planta${l.plantas === 1 ? '' : 's'}`].filter(Boolean)
    return `   · ${l.codigo}${l.genetica ? ` ${l.genetica}` : ''} — ${partes.join(', ')}`
  })

  let cola
  if (deshace) {
    const t = Number(data.tareas_a_cancelar) || 0
    cola = [
      'Se borra su paso a floración (esos días no cuentan en el ciclo)' +
        (t ? ` y se cancela${t === 1 ? '' : 'n'} ${t} tarea${t === 1 ? '' : 's'} de floración pendiente${t === 1 ? '' : 's'}.` : '.'),
      'Las fotos, notas y riegos de esos días quedan.',
    ]
  } else {
    cola = ['Pasar a floración no se deshace sin perder esos días: la planta ya recibió 12/12.']
  }

  return {
    title: deshace
      ? `${plural ? 'Estos lotes vuelven' : 'Este lote vuelve'} a vegetativo como si nunca hubiera${plural ? 'n' : ''} pasado a floración`
      : `Pasar la sala a floración cambia de fase a ${n} lote${plural ? 's' : ''}`,
    message: [...lineas, '', ...cola, '', 'Si lo que querés es mover estos lotes de sala, cancelá y usá "Mover lotes".'].join('\n'),
    confirmText: deshace ? 'Volver a vegetativo' : 'Pasar a floración',
  }
}
