// Cuándo una tarea ya no se hace más: hecha, no hecha (7-oct-2026) o cancelada. Una sola definición
// para todas las pantallas: antes cada una preguntaba `estado !== 'completada'` y una tarea marcada
// «no se hizo» seguía apareciendo como pendiente.
export const ESTADOS_CERRADOS = ['completada', 'no_realizada', 'cancelada']

export const tareaCerrada = (t) => ESTADOS_CERRADOS.includes(t?.estado)
