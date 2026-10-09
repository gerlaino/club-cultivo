import { useConfirm } from './useConfirm.js'

// Descartar o eliminar la ÚLTIMA planta viva cierra el lote (`Lote#cerrar_sin_plantas!`). La regla
// la decide el backend: contesta 409 `ultima_planta` con el aviso ya escrito, y recién con la
// confirmación sigue (`cerrar_lote`). `pedir(cerrarLote)` es el pedido; devuelve su respuesta, o
// null si quien estaba descartando se arrepintió en el aviso.
export function useUltimaPlanta() {
  const { confirm } = useConfirm()
  return async function conAvisoDeCierre(pedir) {
    try {
      return await pedir(false)
    } catch (e) {
      if (e?.response?.status !== 409 || e.response.data?.codigo !== 'ultima_planta') throw e
      const ok = await confirm({
        title: 'Es la última planta', message: e.response.data.error,
        confirmText: 'Sí, cerrar', variant: 'warning',
      })
      return ok ? pedir(true) : null
    }
  }
}
