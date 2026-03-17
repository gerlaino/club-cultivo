<!-- frontend/src/components/PlanBadge.vue -->
<script setup>
import { onMounted } from 'vue'
import { usePlan } from '../composables/usePlan.js'

const { fetchPlan, plan, planLabel, planColor, esTrial } = usePlan()
onMounted(fetchPlan)
</script>

<template>
  <span
    class="badge d-inline-flex align-items-center gap-1"
    :style="{
      background:   planColor.bg,
      color:        planColor.text,
      border:       `1px solid ${planColor.border}`,
      fontSize:     '.68rem',
    }"
  >
    {{ planLabel }}
    <span v-if="esTrial" style="opacity:.7">· Trial</span>
  </span>
</template>
