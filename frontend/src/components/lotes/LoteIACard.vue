<template>
  <div class="lia__card">
    <div class="lia__header">
      <span class="lia__title">🤖 Análisis IA</span>
      <button class="lia__btn-ia" @click="ejecutarAnalisisIA" :disabled="analizandoIA || !puedoAnalizar">
        <DsSpinner v-if="analizandoIA" :size="11" />
        <i v-else class="bi bi-stars"></i>
        <span v-if="analizandoIA">Analizando…</span>
        <span v-else-if="!puedoAnalizar">{{ tiempoRestante }}</span>
        <span v-else>{{ historialAnalisis.length ? 'Nuevo análisis' : 'Analizar lote' }}</span>
      </button>
    </div>

    <div v-if="historialAnalisis.length" class="lia__historial">
      <div v-for="(analisis, idx) in historialAnalisis" :key="analisis.id" class="lia__item">
        <button class="lia__item-header" @click="toggleAnalisis(analisis.id)">
          <div class="lia__meta">
            <i class="bi bi-clock"></i>
            {{ formatearFechaRelativa(analisis.created_at) }}
            <span v-if="idx === 0" class="lia__badge">último</span>
            <span v-if="analisis.tokens_usados" class="lia__tokens">{{ analisis.tokens_usados }} tokens</span>
          </div>
          <i class="bi" :class="expandedAnalisis === analisis.id ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
        </button>
        <div v-if="expandedAnalisis === analisis.id" class="lia__contenido">{{ analisis.contenido }}</div>
      </div>
    </div>

    <div v-else-if="!analizandoIA" class="lia__empty">
      <i class="bi bi-stars"></i>
      <span>Generá un análisis experto del historial de este lote</span>
    </div>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useLoteAnalisisIA } from '../../composables/useLoteAnalisisIA.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  loteId: { type: Number, required: true },
})

const {
  analizandoIA, historialAnalisis, expandedAnalisis,
  puedoAnalizar, tiempoRestante,
  toggleAnalisis, formatearFechaRelativa, cargarHistorialAnalisis, ejecutarAnalisisIA,
} = useLoteAnalisisIA(props.loteId)

onMounted(() => cargarHistorialAnalisis())
</script>

<style scoped>
.lia__card { background: #fff; border: 1px solid #e9d8fd; border-radius: 14px; overflow: hidden; }
.lia__header { display: flex; align-items: center; justify-content: space-between; padding: .8rem 1rem; border-bottom: 1px solid #f3e8ff; }
.lia__title { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.lia__btn-ia { background: linear-gradient(135deg, #7c3aed, #9333ea); color: #fff; border: none; padding: .3rem .75rem; border-radius: 6px; font-size: .75rem; font-weight: 700; cursor: pointer; display: flex; align-items: center; gap: .35rem; }
.lia__btn-ia:disabled { opacity: .6; cursor: not-allowed; }
.lia__historial { display: flex; flex-direction: column; }
.lia__item { border-top: 1px solid #f3e8ff; }
.lia__item:first-child { border-top: none; }
.lia__item-header { width: 100%; display: flex; justify-content: space-between; align-items: center; padding: .5rem 1rem; background: none; border: none; cursor: pointer; text-align: left; }
.lia__item-header:hover { background: #faf5ff; }
.lia__meta { display: flex; align-items: center; gap: .4rem; font-size: .7rem; color: var(--c-slate-400); }
.lia__badge { background: #7c3aed; color: #fff; padding: .1em .45em; border-radius: 4px; font-size: .65rem; font-weight: 700; text-transform: uppercase; }
.lia__tokens { background: #f3e8ff; color: #7c3aed; padding: .1em .45em; border-radius: 4px; font-size: .68rem; font-weight: 600; }
.lia__contenido { font-size: .82rem; color: var(--c-slate-700); line-height: 1.65; white-space: pre-wrap; max-height: 320px; overflow-y: auto; padding: .4rem 1rem .9rem; }
.lia__empty { display: flex; flex-direction: column; align-items: center; gap: .4rem; padding: 1.2rem 1rem; color: var(--c-slate-400); font-size: .8rem; }
.lia__empty i { font-size: 1.4rem; }
</style>
