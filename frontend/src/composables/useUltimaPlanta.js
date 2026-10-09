import { useAvisoConfirmable } from './useAvisoConfirmable.js'

// Descartar o eliminar la ÚLTIMA planta viva cierra el lote (`Lote#cerrar_sin_plantas!`): el backend
// contesta 409 `ultima_planta` y recién con la confirmación sigue (`cerrar_lote`).
export const useUltimaPlanta = () =>
  useAvisoConfirmable({ codigo: 'ultima_planta', title: 'Es la última planta', confirmText: 'Sí, cerrar' })
