<template>
  <div class="sc">
    <div class="sc__header">
      <h1 class="sc__title">Socios en riesgo</h1>
      <p class="sc__sub">Socios que requieren atención inmediata por REPROCANN vencido, próximo a vencer o sin dispensación reciente.</p>
    </div>

    <div v-if="loading" class="sc__loading">Cargando…</div>

    <template v-else-if="datos">
      <!-- REPROCANN vencido -->
      <section v-if="datos.reprocann_vencidos.length > 0" class="sc__group sc__group--error">
        <div class="sc__group-header">
          <span class="sc__group-dot sc__group-dot--error"></span>
          <h2 class="sc__group-title">REPROCANN vencido</h2>
          <span class="sc__group-count">{{ datos.reprocann_vencidos.length }}</span>
        </div>
        <div class="sc__list">
          <RouterLink
            v-for="p in datos.reprocann_vencidos"
            :key="p.id"
            :to="`/socios/${p.id}`"
            class="sc__item"
          >
            <div class="sc__item-nombre">{{ p.nombre }}</div>
            <span class="sc__item-badge sc__item-badge--error">
              Vencido hace {{ p.dias_vencido }}d
            </span>
          </RouterLink>
        </div>
      </section>

      <!-- REPROCANN por vencer -->
      <section v-if="datos.reprocann_por_vencer.length > 0" class="sc__group sc__group--amber">
        <div class="sc__group-header">
          <span class="sc__group-dot sc__group-dot--amber"></span>
          <h2 class="sc__group-title">REPROCANN por vencer (≤30 días)</h2>
          <span class="sc__group-count">{{ datos.reprocann_por_vencer.length }}</span>
        </div>
        <div class="sc__list">
          <RouterLink
            v-for="p in datos.reprocann_por_vencer"
            :key="p.id"
            :to="`/socios/${p.id}`"
            class="sc__item"
          >
            <div class="sc__item-nombre">{{ p.nombre }}</div>
            <span
              class="sc__item-badge"
              :class="p.dias_restantes <= 7 ? 'sc__item-badge--error' : 'sc__item-badge--amber'"
            >
              {{ p.dias_restantes }}d restantes
            </span>
          </RouterLink>
        </div>
      </section>

      <!-- Sin dispensación reciente -->
      <section v-if="datos.sin_dispensacion_reciente.length > 0" class="sc__group sc__group--neutral">
        <div class="sc__group-header">
          <span class="sc__group-dot sc__group-dot--neutral"></span>
          <h2 class="sc__group-title">Sin dispensación en 60 días</h2>
          <span class="sc__group-count">{{ datos.sin_dispensacion_reciente.length }}</span>
        </div>
        <div class="sc__list">
          <RouterLink
            v-for="p in datos.sin_dispensacion_reciente"
            :key="p.id"
            :to="`/socios/${p.id}`"
            class="sc__item"
          >
            <div class="sc__item-nombre">{{ p.nombre }}</div>
            <span class="sc__item-badge sc__item-badge--neutral">Sin retiro</span>
          </RouterLink>
        </div>
      </section>

      <div v-if="datos.total === 0" class="sc__empty">
        No hay socios con situaciones críticas pendientes.
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getPacientesCriticos } from '../lib/api.js'

const loading = ref(true)
const datos   = ref(null)

onMounted(async () => {
  try {
    const { data } = await getPacientesCriticos()
    datos.value = data
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.sc { max-width: 780px; margin: 0 auto; padding: 1.5rem 1.25rem; display: flex; flex-direction: column; gap: 1.5rem; }
@media (max-width: 640px) { .sc { padding: 1rem .75rem 80px; } }

.sc__header {}
.sc__title { font-size: 1.4rem; font-weight: 700; color: #0f2611; margin: 0 0 .25rem; letter-spacing: -.025em; }
.sc__sub   { font-size: .875rem; color: #60725d; margin: 0; line-height: 1.5; }
.sc__loading { font-size: .875rem; color: #60725d; }
.sc__empty   { font-size: .875rem; color: #60725d; background: #f6faf6; border: 1px solid #e8f0e9; border-radius: 12px; padding: 1.5rem; text-align: center; }

.sc__group { border: 1px solid #e8f0e9; border-radius: 12px; overflow: hidden; }
.sc__group--error  { border-color: #fca5a5; }
.sc__group--amber  { border-color: #fcd34d; }
.sc__group--neutral{ border-color: #e8f0e9; }

.sc__group-header { display: flex; align-items: center; gap: .5rem; padding: .65rem 1rem; background: #fafcfa; border-bottom: 1px solid #e8f0e9; }
.sc__group--error  .sc__group-header { background: #fef2f2; border-color: #fca5a5; }
.sc__group--amber  .sc__group-header { background: #fffbeb; border-color: #fcd34d; }

.sc__group-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.sc__group-dot--error   { background: #dc2626; }
.sc__group-dot--amber   { background: #d97706; }
.sc__group-dot--neutral { background: #94a3b8; }

.sc__group-title { font-size: .82rem; font-weight: 700; color: #0f2611; margin: 0; flex: 1; }
.sc__group-count { font-size: .7rem; font-weight: 700; background: #e8f0e9; color: #0f2611; padding: .15em .5em; border-radius: 6px; }
.sc__group--error  .sc__group-count { background: #fde8e8; color: #dc2626; }
.sc__group--amber  .sc__group-count { background: #fef3c7; color: #d97706; }

.sc__list { display: flex; flex-direction: column; }
.sc__item { display: flex; align-items: center; justify-content: space-between; padding: .6rem 1rem; text-decoration: none; color: inherit; border-bottom: 1px solid #f8fafc; transition: background .1s; }
.sc__item:last-child { border-bottom: none; }
.sc__item:hover { background: #f6faf6; }
.sc__item-nombre { font-size: .875rem; font-weight: 600; color: #0f2611; }
.sc__item-badge { font-size: .7rem; font-weight: 700; padding: .2em .6em; border-radius: 6px; white-space: nowrap; }
.sc__item-badge--error   { background: #fef2f2; color: #dc2626; }
.sc__item-badge--amber   { background: #fffbeb; color: #d97706; }
.sc__item-badge--neutral { background: #f1f5f9; color: #64748b; }
</style>
