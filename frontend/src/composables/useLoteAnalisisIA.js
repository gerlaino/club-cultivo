import { ref, computed } from 'vue'
import { useToast } from './useToast.js'
import { analizarLote, getHistorialAnalisis } from '../lib/api'

export function useLoteAnalisisIA(loteId) {
  const toast = useToast()

  const analizandoIA      = ref(false)
  const historialAnalisis = ref([])
  const cooldownHasta     = ref(null)
  const expandedAnalisis  = ref(null)

  const puedoAnalizar = computed(() =>
    !cooldownHasta.value || new Date() > new Date(cooldownHasta.value)
  )

  const tiempoRestante = computed(() => {
    if (!cooldownHasta.value) return ''
    const mins = Math.round((new Date(cooldownHasta.value) - new Date()) / 60000)
    if (mins <= 0) return ''
    return mins < 60 ? `en ${mins} min` : `en ${Math.ceil(mins / 60)}h`
  })

  function toggleAnalisis(id) {
    expandedAnalisis.value = expandedAnalisis.value === id ? null : id
  }

  function formatearFechaRelativa(ts) {
    if (!ts) return ''
    const diff = Date.now() - new Date(ts).getTime()
    const mins = Math.floor(diff / 60000)
    if (mins < 2)  return 'hace un momento'
    if (mins < 60) return `hace ${mins} min`
    const hrs = Math.floor(mins / 60)
    if (hrs < 24)  return `hace ${hrs}h`
    return `hace ${Math.floor(hrs / 24)}d`
  }

  async function cargarHistorialAnalisis() {
    try {
      const { data } = await getHistorialAnalisis(loteId)
      historialAnalisis.value = data.analisis || []
      cooldownHasta.value     = data.cooldown_hasta || null
      if (historialAnalisis.value.length) {
        expandedAnalisis.value = historialAnalisis.value[0].id
      }
    } catch {}
  }

  async function ejecutarAnalisisIA() {
    if (analizandoIA.value || !puedoAnalizar.value) return
    analizandoIA.value = true
    try {
      const { data } = await analizarLote(loteId)
      cooldownHasta.value = data.cooldown_hasta || null
      if (!data.cached) {
        historialAnalisis.value = [data, ...historialAnalisis.value].slice(0, 3)
        expandedAnalisis.value  = data.id
      } else {
        toast.info('Ya existe un análisis reciente. ' + (tiempoRestante.value ? `Próximo disponible ${tiempoRestante.value}.` : ''))
      }
    } catch (e) {
      toast.error(e?.response?.data?.error || 'Error al analizar con IA')
    } finally {
      analizandoIA.value = false
    }
  }

  return {
    analizandoIA, historialAnalisis, cooldownHasta, expandedAnalisis,
    puedoAnalizar, tiempoRestante,
    toggleAnalisis, formatearFechaRelativa, cargarHistorialAnalisis, ejecutarAnalisisIA,
  }
}
