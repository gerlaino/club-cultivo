import { useAvisoConfirmable } from './useAvisoConfirmable.js'

// Una tarea de más adelante se puede dar por hecha, con aviso, y queda hecha HOY (9-oct-2026): el
// backend contesta 409 `tarea_futura` con su fecha y recién con la confirmación sigue (`adelantar`).
export const useTareaFutura = () =>
  useAvisoConfirmable({ codigo: 'tarea_futura', title: 'Es para más adelante', confirmText: 'Sí, hecha hoy' })
