import { useConfirm } from './useConfirm'
import { reabrirPesajeManicura } from '../lib/api'

// Envuelve una llamada de registro de peso de manicura para manejar el aviso del backend
// (409 { needs_choice }) cuando ya hay una jornada ENVIADA sin confirmar de este lote.
// En vez de crear una jornada nueva en silencio, le pregunta a la manicura:
//   - "Seguir la anterior" → reabre esa jornada (vuelve a borrador) y reintenta → suma ahí.
//   - "Empezar una nueva"  → reintenta con force_new (jornada aparte, ambas suman al confirmar).
//
// Uso:
//   const { registrarConJornada } = useManicuraJornada()
//   await registrarConJornada(loteId, (extra) => registrarPesoPlanta(plantId, { ...payload, ...extra }))
// `fn(extra)` debe hacer la llamada mergeando `extra` (que puede traer { force_new: true }).
export function useManicuraJornada() {
  const { confirm } = useConfirm()

  async function registrarConJornada(loteId, fn) {
    try {
      return await fn({})
    } catch (e) {
      const data = e?.response?.data
      if (e?.response?.status !== 409 || !data?.needs_choice) throw e

      const j = data.jornada_enviada || {}
      const seguir = await confirm({
        title:       'Jornada enviada sin confirmar',
        variant:     'default',
        message:     `Ya tenés una jornada de este lote enviada (${j.plantas ?? '?'} plantas · ${j.gramos ?? '?'}g) esperando confirmación del admin. ¿Seguir sumando a esa jornada, o empezar una nueva?`,
        confirmText: 'Seguir la anterior',
        cancelText:  'Empezar una nueva',
      })

      if (seguir) {
        if (j.id) await reabrirPesajeManicura(loteId, j.id)
        return await fn({})
      }
      return await fn({ force_new: true })
    }
  }

  return { registrarConJornada }
}
