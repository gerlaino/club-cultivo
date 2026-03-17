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
      console.error('Error cargando plan:', e)
    } finally {
      loading.value = false
    }
  }

  const plan      = computed(() => planData.value?.plan      || 'semilla')
  const planLabel = computed(() => planData.value?.label     || 'Semilla')
  const esTrial   = computed(() => planData.value?.trial     || false)
  const limites   = computed(() => planData.value?.limites   || {})
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

  const PLAN_COLORS = {
    semilla:    { bg: '#e8f5e9', text: '#2e7d32', border: '#a5d6a7' },
    brote:      { bg: '#e3f2fd', text: '#1565c0', border: '#90caf9' },
    cosecha:    { bg: '#fff8e1', text: '#f57f17', border: '#ffe082' },
    federacion: { bg: '#f3e5f5', text: '#6a1b9a', border: '#ce93d8' },
  }
  const planColor = computed(() => PLAN_COLORS[plan.value] || PLAN_COLORS.semilla)

  return {
    planData, loading,
    plan, planLabel, esTrial, limites, uso,
    puedeCrear, porcentajeUso, planColor,
    fetchPlan,
  }
}
