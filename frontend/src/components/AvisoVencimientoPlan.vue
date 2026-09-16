<script setup>
// «Tu plan vence el…», en la app de la organización. Hasta sep-2026 `plan_activo_hasta` lo
// leía sólo el panel de plataforma: el admin no tenía forma de saber cuándo vencía. Aparece
// siete días antes y se queda cuando venció; es informativo, la app sigue andando (el corte,
// si algún día existe, es otra decisión). Sólo para el admin: es quien puede hacer algo.
import { computed } from 'vue'
import { usePlan } from '../composables/usePlan.js'
import { useAuthStore } from '../stores/auth'

const { planData } = usePlan()
const auth = useAuthStore()
const DIAS_AVISO = 7

const dias = computed(() => {
  const hasta = planData.value?.activo_hasta
  if (!hasta) return null
  const h = new Date(hasta + 'T00:00:00')
  const hoy = new Date(); hoy.setHours(0, 0, 0, 0)
  return Math.round((h - hoy) / 86400000)
})

const visible = computed(() => auth.user?.role === 'admin' && dias.value !== null && dias.value <= DIAS_AVISO)
const vencido = computed(() => dias.value !== null && dias.value < 0)

const fecha = computed(() => {
  const hasta = planData.value?.activo_hasta
  return hasta ? new Date(hasta + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'long' }) : ''
})

const texto = computed(() => {
  if (dias.value < 0)   return `El plan de la organización venció el ${fecha.value}. La app sigue andando: hablá con Cultivo Espacial para renovarlo.`
  if (dias.value === 0) return `El plan de la organización vence hoy. Hablá con Cultivo Espacial para renovarlo.`
  if (dias.value === 1) return `El plan de la organización vence mañana (${fecha.value}). Hablá con Cultivo Espacial para renovarlo.`
  return `El plan de la organización vence el ${fecha.value}, en ${dias.value} días. Hablá con Cultivo Espacial para renovarlo.`
})
</script>

<template>
  <div v-if="visible" class="avp" :class="{ 'avp--vencido': vencido }" role="status">
    <i class="bi" :class="vencido ? 'bi-exclamation-octagon' : 'bi-calendar-event'"></i>
    <span>{{ texto }}</span>
  </div>
</template>

<style scoped>
.avp {
  display: flex; align-items: center; gap: .55rem;
  padding: .5rem 1.25rem; font-size: .8rem; font-weight: 600;
  background: var(--c-amber-100, #FEF3C7); color: #92400e; border-bottom: 1px solid #fde68a;
}
.avp--vencido { background: var(--c-rust-100, #FEE2E2); color: #991b1b; border-bottom-color: #fecaca; }
</style>
