import { useConfirm } from './useConfirm.js'

// Un pedido que el backend frena con un aviso para confirmar: contesta 409 con `codigo` y el texto
// ya escrito (la regla vive allá), la pantalla lo muestra y, si se confirma, repite el pedido con
// la confirmación. `pedir(confirmado)` es el pedido; devuelve su respuesta, o null si quien lo hacía
// se arrepintió en el aviso. Cualquier otro error sigue de largo.
export function useAvisoConfirmable({ codigo, title, confirmText, variant = 'warning' }) {
  const { confirm } = useConfirm()
  return async function conAviso(pedir) {
    try {
      return await pedir(false)
    } catch (e) {
      if (e?.response?.status !== 409 || e.response.data?.codigo !== codigo) throw e
      const ok = await confirm({ title, message: e.response.data.error, confirmText, variant })
      return ok ? pedir(true) : null
    }
  }
}
