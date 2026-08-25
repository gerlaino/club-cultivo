import { logger } from '../utils/logger.js'
// frontend/src/composables/usePlan.js
import { ref, computed } from 'vue'
import { getPlan } from '../lib/api'

const planData = ref(null)
const loading  = ref(false)

export function usePlan() {

  async function fetchPlan() {
    if (planData.value) return
    loading.value = true
    try {
      const { data } = await getPlan()
      planData.value = data
    } catch (e) {
      logger.error('Error cargando plan:', e)
    } finally {
      loading.value = false
    }
  }

  // Los defaults eran 'semilla'/'Semilla', que son los planes VIEJOS: hoy son dos, `basico` y
  // `total` (PlanEnforcer::PLANES). Mientras la llamada estaba en vuelo la pantalla mostraba un
  // plan que no existe.
  const plan      = computed(() => planData.value?.plan      || 'basico')
  const planLabel = computed(() => planData.value?.label     || 'Básico')
  const esTrial   = computed(() => planData.value?.trial     || false)
  const limites   = computed(() => planData.value?.limites   || {})
  // El cupo de usuarios dejó de ser un número y pasó a ser "uno de cada rol": viaja aparte de
  // `limites` porque no se puede dibujar como una barra de uso.
  const usuariosPorRol = computed(() => planData.value?.usuarios_por_rol ?? null)
  const uso       = computed(() => planData.value?.uso       || {})

  function puedeCrear(recurso) {
    const limite = limites.value[recurso]
    if (limite === null || limite === undefined) return true
    return (uso.value[recurso] || 0) < limite
  }

  function porcentajeUso(recurso) {
    const limite = limites.value[recurso]
    if (!limite) return 0
    return Math.min(100, Math.round(((uso.value[recurso] || 0) / limite) * 100))
  }

  // Los cuatro planes viejos siguen mapeados por si aparece uno guardado (igual que
  // `PlanEnforcer::PLANES_LEGACY`), pero los que se pintan hoy son dos.
  const PLAN_COLORS = {
    basico:     { bg: '#e8f5e9', text: '#2e7d32', border: '#a5d6a7' },
    total:      { bg: '#f3e5f5', text: '#6a1b9a', border: '#ce93d8' },
    semilla:    { bg: '#e8f5e9', text: '#2e7d32', border: '#a5d6a7' },
    brote:      { bg: '#e3f2fd', text: '#1565c0', border: '#90caf9' },
    cosecha:    { bg: '#fff8e1', text: '#f57f17', border: '#ffe082' },
    federacion: { bg: '#f3e5f5', text: '#6a1b9a', border: '#ce93d8' },
  }
  const planColor = computed(() => PLAN_COLORS[plan.value] || PLAN_COLORS.basico)

  return {
    planData, loading,
    plan, planLabel, esTrial, limites, uso, usuariosPorRol,
    puedeCrear, porcentajeUso, planColor,
    fetchPlan,
  }
}
