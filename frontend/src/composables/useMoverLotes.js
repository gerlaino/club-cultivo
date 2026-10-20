// Mover lotes de sala: pregunta con lo que el BACKEND dice que va a pasar (`simular`) y después
// mueve. Lo usan la sala, la lista de lotes y la ficha del teléfono (20-oct-2026): antes cada
// pantalla calculaba por su cuenta qué lotes cambiaban de fase, y eran dos copias de la regla.
import { ref } from 'vue'
import { moverLotes, simularMoverLotes } from '../lib/api'
import { useToast } from './useToast'
import { useConfirm } from './useConfirm.js'

const lotes = n => (n === 1 ? '1 lote' : `${n} lotes`)
const errorDe = (e, porDefecto) => e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || porDefecto

export function useMoverLotes() {
  const toast = useToast()
  const { confirm } = useConfirm()
  const moviendo = ref(false)

  // Devuelve la respuesta del backend si se movió; null si se canceló o falló.
  async function mover(loteIds, destino) {
    if (!destino || !loteIds.length) return null
    moviendo.value = true
    try {
      const { data: plan } = await simularMoverLotes(loteIds, destino.id)
      if (!plan.movidos) { toast.warning(`Ya ${loteIds.length === 1 ? 'está' : 'están'} en ${destino.nombre}`); return null }

      const lineas = [`Vas a mover ${lotes(plan.movidos)} a "${destino.nombre}".`]
      if (plan.cambia_sede) lineas.push(`Atención: es de OTRA SEDE: pasan a ${plan.sede_destino || 'esa sede'} y sus costos se imputan ahí.`)
      const cambios = plan.cambios_de_fase || []
      if (cambios.length) {
        lineas.push(cambios.length === 1 ? 'Atención: la sala le cambia la fase:' : 'Atención: la sala cambia la fase de estos lotes:')
        lineas.push(...cambios.map(c => `   · ${c.codigo}: ${c.de_label} → ${c.a_label}`))
        if (cambios.some(c => c.a === 'floracion')) lineas.push('Pasar a floración no se deshace: la planta ya recibió 12/12.')
      }
      const ok = await confirm({
        title: 'Mover de sala', message: lineas.join('\n'),
        variant: cambios.length ? 'danger' : 'warning', confirmText: 'Mover',
      })
      if (!ok) return null

      const { data } = await moverLotes(loteIds, destino.id)
      const extra = data.cambios_de_fase?.length ? ` · ${data.cambios_de_fase.length} cambiaron de fase` : ''
      toast.success(`${data.movidos === 1 ? 'Lote movido' : `${data.movidos} lotes movidos`} a ${destino.nombre}${extra}`)
      return data
    } catch (e) {
      toast.error(errorDe(e, 'No se pudieron mover'))
      return null
    } finally { moviendo.value = false }
  }

  return { mover, moviendo }
}
